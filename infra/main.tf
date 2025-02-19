resource "aws_lambda_function" "bedrock_sentences" {
  filename         = "../lambda.zip"
  function_name    = "bedrock-sentences"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  source_code_hash = filebase64sha256("../lambda.zip")
  runtime          = "provided.al2"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  environment {
    variables = {
      MODEL_ID = var.model_id
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.bedrock_sentences.function_name}"
  retention_in_days = 1
}

resource "aws_iam_role" "lambda_role" {
  name = "bedrock_sentences_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_policy" {
  name = "bedrock_access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_api_gateway_rest_api" "lambda_api" {
  name = "bedrock-sentences-api"
}

resource "aws_api_gateway_resource" "sentences" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "sentences"
}

resource "aws_api_gateway_resource" "word" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_resource.sentences.id
  path_part   = "{word}"
}

resource "aws_api_gateway_method" "get_word" {
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  resource_id      = aws_api_gateway_resource.word.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.get_word.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.bedrock_sentences.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.get_word,
    aws_api_gateway_gateway_response.quota_exceeded
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.get_word.api_key_required,
      aws_api_gateway_method.get_word.authorization,
      aws_api_gateway_integration.lambda_integration.uri,
      aws_api_gateway_gateway_response.quota_exceeded,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_sentences.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}

resource "aws_api_gateway_api_key" "sentences_api_key" {
  name = "sentences-api-key"
}

resource "aws_api_gateway_usage_plan" "sentences_usage_plan" {
  name = "sentences-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.lambda_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = var.daily_request_limit
    period = "DAY"
  }
}

resource "aws_api_gateway_usage_plan_key" "sentences_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.sentences_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.sentences_usage_plan.id
}

resource "aws_api_gateway_gateway_response" "quota_exceeded" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  response_type = "QUOTA_EXCEEDED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      message = "Try again tomorrow (Hey, it's free and querying LLMs is expensive!)"
      code    = "DAILY_QUOTA_EXCEEDED"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}
