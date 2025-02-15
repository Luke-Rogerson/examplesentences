variable "project_name" {
  description = "The name of the project"
  default     = "example-sentences"
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  default     = "eu-west-1"
}

variable "environment" {
  description = "The environment to deploy resources in"
  default     = "nonprod"
}


