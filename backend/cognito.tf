
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


