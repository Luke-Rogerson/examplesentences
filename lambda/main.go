package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
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
	// Convert payload to JSON
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

	responseJSON, err := json.Marshal(responseBody)
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
