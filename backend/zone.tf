
data "aws_route53_zone" "app_zone" {
  name = format("%s.", var.domain_name)
}
