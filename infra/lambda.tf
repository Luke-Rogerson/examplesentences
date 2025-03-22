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

