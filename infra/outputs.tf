output "api_endpoint" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/sentences/{word}"
  description = "API Gateway endpoint URL"
}

