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

variable "model_id" {
  description = "The model ID to use"
  default     = "amazon.nova-lite-v1:0"
}

variable "lambda_timeout" {
  description = "The timeout for the lambda function"
  default     = 10
}

variable "lambda_memory_size" {
  description = "The memory size for the lambda function"
  default     = 256
}
