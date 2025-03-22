resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.bedrock_sentences.function_name}"
  retention_in_days = var.cloudwatch_retention_days
}
