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

# API Gateway
variable "enable_request_quotas" {
  description = "Whether to enable request quotas"
  default     = true
}

variable "daily_request_limit" {
  description = "Maximum number of API requests allowed per day"
  type        = number
  default     = 10
}
