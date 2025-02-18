# WAF Configuration
resource "aws_wafv2_web_acl" "api_waf" {
  name        = "bedrock-sentences-waf"
  description = "WAF for bedrock sentences API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }


  rule {
    name     = "IPRateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.ip_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IPRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Request Counter Rule
  # rule {
  #   name     = "RequestCounter"
  #   priority = 2

  #   override_action {
  #     none {}
  #   }

  #   statement {
  #     byte_match_statement {
  #       search_string         = "/"
  #       positional_constraint = "CONTAINS"

  #       field_to_match {
  #         uri_path {}
  #       }

  #       text_transformation {
  #         priority = 1
  #         type     = "NONE"
  #       }
  #     }
  #   }

  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "TotalRequestsMetric"
  #     sampled_requests_enabled   = true
  #   }
  # }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "BedrockSentencesWAFMetrics"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with API Gateway Stage
resource "aws_wafv2_web_acl_association" "api_waf" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.api_waf.arn
}

