resource "aws_acm_certificate" "backend_cert" {
  domain_name       = var.backend_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
