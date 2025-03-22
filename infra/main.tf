resource "aws_lambda_function" "bedrock_sentences" {
  filename                       = "../lambda.zip"
  function_name                  = "${local.name_env_prefix}-backend"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "bootstrap"
  source_code_hash               = filebase64sha256("../lambda.zip")
  runtime                        = "provided.al2"
  timeout                        = var.lambda_timeout
  memory_size                    = var.lambda_memory_size
  reserved_concurrent_executions = var.lambda_concurrent_executions
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
  name = "${local.name_env_prefix}-bedrock-sentences-lambda-role"

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
  name = "${local.name_env_prefix}-bedrock-access"
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
  name = "${local.name_env_prefix}-rest-api"

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "word" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "{word}"
}

resource "aws_api_gateway_method" "get_word" {
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  resource_id      = aws_api_gateway_resource.word.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = var.enable_request_quotas ? true : false
}

resource "aws_api_gateway_method" "options_word" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_resource.word.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.get_word.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.bedrock_sentences.invoke_arn
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.options_word.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.options_word.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.get_word,
    aws_api_gateway_gateway_response.quota_exceeded,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_method.options_word,
    aws_api_gateway_method_response.options_200,
    aws_api_gateway_integration_response.options_integration_response
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.get_word.api_key_required,
      aws_api_gateway_method.get_word.authorization,
      aws_api_gateway_integration.lambda_integration.uri,
      aws_api_gateway_gateway_response.quota_exceeded,
      aws_api_gateway_gateway_response.lambda_throttled,
      aws_api_gateway_gateway_response.lambda_throttled_explicit,
      aws_api_gateway_resource.word.path_part,
      aws_api_gateway_method.options_word.http_method,
      aws_api_gateway_integration.options_integration.type,
      aws_api_gateway_method_response.options_200.response_parameters,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.options_word.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "get_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.word.id
  http_method = aws_api_gateway_method.get_word.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
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
  name = "${local.name_env_prefix}-api-key"
}

resource "aws_api_gateway_usage_plan" "sentences_usage_plan" {
  name  = "${local.name_env_prefix}-usage-plan"
  count = var.enable_request_quotas ? 1 : 0

  api_stages {
    api_id = aws_api_gateway_rest_api.lambda_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = var.daily_request_limit
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = var.rate_limit
    burst_limit = var.rate_limit * 3
  }
}

resource "aws_api_gateway_usage_plan_key" "sentences_usage_plan_key" {
  count         = var.enable_request_quotas ? 1 : 0
  key_id        = aws_api_gateway_api_key.sentences_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.sentences_usage_plan[0].id
}

resource "aws_api_gateway_gateway_response" "quota_exceeded" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  response_type = "QUOTA_EXCEEDED"
  status_code   = "430"

  response_templates = {
    "application/json" = jsonencode({
      message = "DAILY_QUOTA_EXCEEDED - Try again tomorrow (Hey, LLMs are expensive and we're not charging you anything!)"
      code    = "DAILY_QUOTA_EXCEEDED"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "lambda_throttled" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  response_type = "INTEGRATION_FAILURE"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      message = "RATE_LIMIT_EXCEEDED - Slow down, sir. Remember this is a free service."
      code    = "RATE_LIMIT_EXCEEDED"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "lambda_throttled_explicit" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      message = "THROTTLED - Ease up. Remember this is a free service."
      code    = "THROTTLED"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}


resource "aws_api_gateway_domain_name" "backend_domain" {
  domain_name              = var.backend_domain
  regional_certificate_arn = aws_acm_certificate.backend_cert.arn

  depends_on = [aws_acm_certificate.backend_cert]
}

resource "aws_api_gateway_base_path_mapping" "backend_mapping" {
  api_id      = aws_api_gateway_rest_api.lambda_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.backend_domain.domain_name
  base_path   = "" # Empty string means root path
}

resource "aws_acm_certificate" "backend_cert" {
  domain_name       = var.backend_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
