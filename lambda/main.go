package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"strings"
	"unicode"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

type Message struct {
	Role    string    `json:"role"`
	Content []Content `json:"content"`
}

type Content struct {
	Text string `json:"text"`
}

type InferenceConfig struct {
	MaxNewTokens int `json:"max_new_tokens"`
}

type RequestPayload struct {
	InferenceConfig InferenceConfig `json:"inferenceConfig"`
	Messages        []Message       `json:"messages"`
}

type ParsedSentence struct {
	Target        string `json:"target"`
	English       string `json:"english"`
	Pronunciation string `json:"pronunciation"`
}

type FormattedResponse struct {
	Message   string           `json:"message"`
	Sentences []ParsedSentence `json:"sentences"`
}

type Response struct {
	StatusCode int               `json:"statusCode"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
}

var (
	awsConfig aws.Config
	bdrClient *bedrockruntime.Client
)

const (
	maxWordLength = 50
	minWordLength = 1
)

func buildPayload(word string) RequestPayload {
	return RequestPayload{
		InferenceConfig: InferenceConfig{
			MaxNewTokens: 1000,
		},
		Messages: []Message{
			{
				Role: "user",
				Content: []Content{
					{
						Text: fmt.Sprintf("Generate five example sentences for '%s'.\n"+
							"Each sentence must show different usages.\n"+
							"Format each entry as:\n"+
							"T: (Target language sentence)\n"+
							"E: (English translation)\n"+
							"P: (Pronunciation guide)\n"+
							"Separate each entry with a line break.\n"+
							"Do not include extra text or explanations.", word),
					},
				},
			},
		},
	}
}

func init() {
	var err error
	awsConfig, err = config.LoadDefaultConfig(context.Background(),
		config.WithRegion(os.Getenv("AWS_REGION")),
	)
	if err != nil {
		panic(err)
	}
	bdrClient = bedrockruntime.NewFromConfig(awsConfig)
}

func validateWord(word string) (string, error) {
	if len(word) < minWordLength {
		return "", fmt.Errorf("word must be at least %d character", minWordLength)
	}
	if len(word) > maxWordLength {
		return "", fmt.Errorf("word must not exceed %d characters", maxWordLength)
	}

	decodedWord, err := url.QueryUnescape(word)
	if err != nil {
		return "", fmt.Errorf("invalid URL encoding: %s", err.Error())
	}

	for _, r := range decodedWord {
		if !unicode.Is(unicode.Han, r) && // Chinese characters
			!unicode.Is(unicode.Hiragana, r) && // Japanese Hiragana
			!unicode.Is(unicode.Katakana, r) && // Japanese Katakana
			!unicode.Is(unicode.Hangul, r) && // Korean characters
			!unicode.IsLetter(r) && // Latin and other alphabets
			r != '-' && r != ' ' { // Allow hyphens and spaces
			return "", fmt.Errorf("word contains invalid characters")
		}
	}

	return decodedWord, nil
}

func parseEntry(entry string) (*ParsedSentence, error) {
	lines := strings.Split(strings.TrimSpace(entry), "\n")

	// Check if we have exactly 3 lines
	if len(lines) != 3 {
		return nil, fmt.Errorf("invalid entry format: expected 3 lines, got %d", len(lines))
	}

	// Verify each line starts with the expected prefix
	prefixes := map[string]bool{
		"T: ": false,
		"E: ": false,
		"P: ": false,
	}

	sentence := &ParsedSentence{}

	for _, line := range lines {
		switch {
		case strings.HasPrefix(line, "T: "):
			sentence.Target = strings.TrimPrefix(line, "T: ")
			prefixes["T: "] = true
		case strings.HasPrefix(line, "E: "):
			sentence.English = strings.TrimPrefix(line, "E: ")
			prefixes["E: "] = true
		case strings.HasPrefix(line, "P: "):
			sentence.Pronunciation = strings.TrimPrefix(line, "P: ")
			prefixes["P: "] = true
		}
	}

	// Check if all prefixes were found
	for prefix, found := range prefixes {
		if !found {
			return nil, fmt.Errorf("missing expected line with prefix '%s'", prefix)
		}
	}

	return sentence, nil
}

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (Response, error) {
	log.Printf("--------------------------------")
	log.Printf("Request URL: %s%s", request.Headers["Host"], request.Path)
	log.Printf("--------------------------------")

	word := request.PathParameters["word"]

	validatedWord, err := validateWord(word)
	if err != nil {
		return Response{
			StatusCode: 400,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: fmt.Sprintf(`{"error": "Invalid word: %s"}`, err.Error()),
		}, nil
	}

	// Prepare the payload
	payload := buildPayload(validatedWord)
	fmt.Printf("payload: %#v\n", payload)

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return Response{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: fmt.Sprintf(`{"error": "%s"}`, err.Error()),
		}, nil
	}

	output, err := bdrClient.InvokeModel(ctx, &bedrockruntime.InvokeModelInput{
		ModelId:     aws.String("amazon.nova-lite-v1:0"),
		ContentType: aws.String("application/json"),
		Accept:      aws.String("application/json"),
		Body:        payloadBytes,
	})
	if err != nil {
		return Response{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: fmt.Sprintf(`{"error": "%s"}`, err.Error()),
		}, nil
	}

	var responseBody map[string]interface{}
	if err := json.Unmarshal(output.Body, &responseBody); err != nil {
		return Response{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: fmt.Sprintf(`{"error": "%s"}`, err.Error()),
		}, nil
	}

	// Extract and parse the text content
	content := responseBody["output"].(map[string]interface{})["message"].(map[string]interface{})["content"].([]interface{})[0].(map[string]interface{})["text"].(string)

	// Split the content into individual entries
	entries := strings.Split(strings.TrimSpace(content), "\n\n")

	var parsedSentences []ParsedSentence
	var parseErrors []string

	for i, entry := range entries {
		sentence, err := parseEntry(entry)
		if err != nil {
			parseErrors = append(parseErrors, fmt.Sprintf("entry %d: %s", i+1, err.Error()))
			continue
		}
		parsedSentences = append(parsedSentences, *sentence)
	}

	message := "Success"
	if len(parseErrors) > 0 {
		message = "Failed to generate examples"
	}

	formattedResponse := FormattedResponse{
		Message:   message,
		Sentences: parsedSentences,
	}

	responseJSON, err := json.Marshal(formattedResponse)
	if err != nil {
		return Response{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: fmt.Sprintf(`{"error": "%s"}`, err.Error()),
		}, nil
	}

	return Response{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(responseJSON),
	}, nil
}

func main() {
	lambda.Start(handleRequest)
}
