# General
variable "project_name" {
  description = "The name of the project"
  default     = "example-sentences"
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment to deploy resources in"
  default     = "nonprod"
}

# Bedrock
variable "model_id" {
  description = "The model ID to use"
  default     = "amazon.nova-lite-v1:0"
}

# Lambda
variable "lambda_timeout" {
  description = "The timeout for the lambda function"
  default     = 10
}

variable "lambda_memory_size" {
  description = "The memory size for the lambda function"
  default     = 256
}

# WAF
variable "ip_rate_limit" {
  description = "Number of requests allowed per IP per 5 minutes"
  type        = number
  default     = 10
}

variable "daily_request_limit" {
  description = "Total number of requests allowed per day"
  type        = number
  default     = 15
}
