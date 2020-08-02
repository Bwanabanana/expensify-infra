
locals {
  cloudfront_domain_name = format("%s.%s", var.app_name, var.domain_name)
  cloudfront_origin_name = format("s3.%s", local.cloudfront_domain_name)
}

#
# Cloudfront CDN
#

resource "aws_cloudfront_distribution" "app_distribution" {

  origin {
    domain_name = aws_s3_bucket.app_bucket.website_endpoint
    origin_id   = local.cloudfront_origin_name

    custom_origin_config {
      http_port  = "80"
      https_port = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
    
    custom_header {
      name  = "User-Agent"
      value = var.cloud_front_access_secret
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for Expensify @ BwanaBanana"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs_bucket.bucket_domain_name
    prefix          = "cloudfront/access"
  }

  aliases = [local.cloudfront_domain_name]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.cloudfront_origin_name
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code = 403
    response_code = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["GB"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_certificate.arn
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only" 
  }
}

#
# Domain Records
#

resource "aws_route53_record" "cloudfront_record" {
  zone_id = data.aws_route53_zone.app_zone.zone_id
  name    = aws_s3_bucket.app_bucket.id
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.app_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.app_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

#
# Certificate
#

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

locals {
  # Inspiration: https://github.com/terraform-providers/terraform-provider-aws/issues/8531

  # NOTE: you must taint the certificate (aws_acm_certificate.cloudfront_certificate) when adding new sans
  external_domain_sans = []

  # Add all domain names (including root) to a list
  subject_alternative_names = [for san in local.external_domain_sans : format("%s.%s", san, local.cloudfront_domain_name)]
  domain_names              = concat([local.cloudfront_domain_name], local.subject_alternative_names)

  # Create a map of domain_validation_options by domain names
  validation_options_by_domain = {
    for domain_name in local.domain_names :
    domain_name => [
      for key, value in aws_acm_certificate.cloudfront_certificate.domain_validation_options :
      tomap(value) if domain_name == value.domain_name
    ]
  }
}

resource "aws_acm_certificate" "cloudfront_certificate" {
  provider                  = aws.us-east-1
  domain_name               = local.cloudfront_domain_name
  subject_alternative_names = local.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [subject_alternative_names]
  }
}

resource "aws_route53_record" "validation_records" {
  for_each        = local.validation_options_by_domain
  name            = length(each.value) > 0 ? each.value[0].resource_record_name : "undefined"
  type            = length(each.value) > 0 ? each.value[0].resource_record_type : "CNAME"
  records         = [length(each.value) > 0 ? each.value[0].resource_record_value : "undefined"]
  zone_id         = data.aws_route53_zone.app_zone.zone_id
  ttl             = "60"
  allow_overwrite = true

  depends_on = [
    aws_acm_certificate.cloudfront_certificate
  ]
}

resource "aws_acm_certificate_validation" "cloudfront_certificate_validation" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.cloudfront_certificate.arn
  validation_record_fqdns = values(aws_route53_record.validation_records).*.fqdn
}

