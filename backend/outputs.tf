output "user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}
