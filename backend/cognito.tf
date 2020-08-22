
#
# User Pool
#
resource "aws_cognito_user_pool" "pool" {
  name = format("%s_pool", var.app_name)

  username_configuration {
    case_sensitive = false
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = format("%s_client", var.app_name)
  user_pool_id = aws_cognito_user_pool.pool.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
}

#
# Identity Pool
#
resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = format("%s_identity_pool", var.app_name)
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = aws_cognito_user_pool.pool.endpoint
    server_side_token_check = false
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "attach_get_openapi_role" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  roles = {
    "authenticated" = aws_iam_role.authenticated_user_role.arn
  }
}

resource "aws_iam_role" "authenticated_user_role" {
  name               = format("cognito_user_role_%s", var.app_name)
  assume_role_policy = data.aws_iam_policy_document.sts_assume_role_policy.json
}

data "aws_iam_policy_document" "sts_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        "cognito-identity.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values = [
        aws_cognito_identity_pool.identity_pool.id
      ]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values = [
        "authenticated"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_get_openapi_policy" {
  role       = aws_iam_role.authenticated_user_role.name
  policy_arn = aws_iam_policy.get_openapi_policy.arn
}

resource "aws_iam_policy" "get_openapi_policy" {
  name        = format("get_%s_openapi", var.app_name)
  description = format("Allows openapi for %s app to be retrieved", var.app_name)
  policy      = data.aws_iam_policy_document.get_openapi_policy_document.json
}

data "aws_iam_policy_document" "get_openapi_policy_document" {
  statement {
    actions = [
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE"
    ]
    effect = "Deny"
    resources = [
      "arn:aws:apigateway:eu-west-2::/*"
    ]
  }

  statement {
    actions = [
      "apigateway:GET"
    ]
    effect = "Deny"
    resources = [
      "arn:aws:apigateway:eu-west-2::/",
      "arn:aws:apigateway:eu-west-2::/account",
      "arn:aws:apigateway:eu-west-2::/clientcertificates",
      "arn:aws:apigateway:eu-west-2::/domainnames",
      "arn:aws:apigateway:eu-west-2::/apikeys"
    ]
  }

  statement {
    actions = [
      "apigateway:GET"
    ]
    effect = "Allow"
    resources = [
      format("arn:aws:apigateway:eu-west-2::/restapis/%s/stages/live/exports/oas30", aws_api_gateway_rest_api.app_api.id)
    ]
  }
}
