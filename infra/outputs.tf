output "api_endpoint" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/{word}"
  description = "API Gateway endpoint URL"
}

output "api_key" {
  value     = aws_api_gateway_api_key.sentences_api_key.value
  sensitive = true
}

# This requires manual DNS configuration and validation
output "certificate_validation_records" {
  value = {
    for dvo in aws_acm_certificate.backend_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  description = "The DNS records needed to validate the certificate. Create these in your domain registrar"
}


output "api_gateway_domain" {
  value = {
    domain_name        = aws_api_gateway_domain_name.backend_domain.domain_name
    target_domain_name = aws_api_gateway_domain_name.backend_domain.regional_domain_name
    target_zone_id     = aws_api_gateway_domain_name.backend_domain.regional_zone_id
  }
  description = "Create an A record alias in your domain registrar pointing to this target domain name"
}
