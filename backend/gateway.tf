
locals {
  api_domain_name = format("api.%s.%s", var.app_name, var.domain_name)
}

#
# Base Gateway Config
#
resource "aws_api_gateway_rest_api" "app_api" {
  name           = var.app_name
  api_key_source = "HEADER"
  body           = data.template_file.app_oapi_template.rendered
}

data "template_file" "app_oapi_template" {
  template = file("./openapi.yml")
  vars = {
    root_domain_name                = var.domain_name
    api_domain_name                 = local.api_domain_name
    cognito_user_pool_arn           = aws_cognito_user_pool.pool.arn
    get_expenses_invoke_arn         = aws_lambda_function.get_expenses.invoke_arn
    add_expense_invoke_arn          = aws_lambda_function.add_expense.invoke_arn
    update_expense_invoke_arn       = aws_lambda_function.update_expense.invoke_arn
    delete_expense_invoke_arn       = aws_lambda_function.delete_expense.invoke_arn
    invoke_expenses_lambda_role_arn = aws_iam_role.gateway_invoke_app.arn
  }
}

resource "aws_api_gateway_deployment" "app_api" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id
  stage_name  = "live"

  triggers = {
    redeployment = sha1(data.template_file.app_oapi_template.rendered)
  }

  lifecycle {
    create_before_destroy = true
  }
}

#
# Domain Configuration
#
resource "aws_api_gateway_base_path_mapping" "app_api_domain_mapping" {
  api_id      = aws_api_gateway_rest_api.app_api.id
  stage_name  = aws_api_gateway_deployment.app_api.stage_name
  domain_name = aws_api_gateway_domain_name.app_api.domain_name
}

resource "aws_api_gateway_domain_name" "app_api" {
  domain_name              = local.api_domain_name
  regional_certificate_arn = aws_acm_certificate.api_certificate.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  depends_on = [aws_acm_certificate_validation.api_certificate_validation]
}

resource "aws_route53_record" "api_record" {
  name    = aws_api_gateway_domain_name.app_api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.app_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.app_api.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.app_api.regional_zone_id
  }
}

#
# Certificate
#
resource "aws_acm_certificate" "api_certificate" {
  domain_name       = local.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

#
# Certificate Validation
#
resource "aws_route53_record" "validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.api_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  type    = each.value.type

  zone_id         = data.aws_route53_zone.app_zone.zone_id
  allow_overwrite = true
  ttl             = 60

  depends_on = [
    aws_acm_certificate.api_certificate
  ]
}

resource "aws_acm_certificate_validation" "api_certificate_validation" {
  certificate_arn         = aws_acm_certificate.api_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_records : record.fqdn]
}

#
# API Permissions
#
resource "aws_iam_role" "gateway_invoke_app" {
  name               = format("apigateway_invoke_%s_app", var.app_name)
  assume_role_policy = data.aws_iam_policy_document.gateway_assume_policy.json
}

data "aws_iam_policy_document" "gateway_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "apigateway.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_app_invoke_policy" {
  role       = aws_iam_role.gateway_invoke_app.name
  policy_arn = aws_iam_policy.invoke_app.arn
}

resource "aws_iam_policy" "invoke_app" {
  name        = format("invoke_%s_app", var.app_name)
  description = format("Allows %s app to be invoked", var.app_name)
  policy      = data.aws_iam_policy_document.invoke_app.json
}

data "aws_iam_policy_document" "invoke_app" {
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.get_expenses.arn,
      aws_lambda_function.add_expense.arn,
      aws_lambda_function.update_expense.arn,
      aws_lambda_function.delete_expense.arn
    ]
  }
}
