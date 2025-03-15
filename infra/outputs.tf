output "api_endpoint" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/sentences/{word}"
  description = "API Gateway endpoint URL"
}

output "api_key" {
  value     = aws_api_gateway_api_key.sentences_api_key.value
  sensitive = true
}

