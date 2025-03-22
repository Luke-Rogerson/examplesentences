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
  description = "Environment name (e.g., 'prod', 'nonprod')"
  type        = string
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

variable "lambda_concurrent_executions" {
  description = "Maximum number of concurrent executions for the lambda function"
  type        = number
  default     = 5
}

variable "daily_request_limit" {
  description = "Maximum number of API requests allowed per day"
  type        = number
  default     = 500
}

variable "rate_limit" {
  description = "Maximum number of API requests allowed per second"
  type        = number
  default     = 2
}

variable "backend_domain" {
  description = "The domain name for the backend"
}
