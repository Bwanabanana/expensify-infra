
resource "aws_dynamodb_table" "user_data_table" {
  name         = format("%s-user-data", var.app_name)
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userKey"
  range_key    = "dataKey"

  attribute {
    name = "userKey"
    type = "S"
  }

  attribute {
    name = "dataKey"
    type = "S"
  }
}
