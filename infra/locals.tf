data "aws_caller_identity" "current" {}

locals {
  name_env_prefix = "${var.project_name}-${var.environment}"
}
