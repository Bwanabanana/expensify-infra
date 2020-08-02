
#
# Lambda
#
resource "aws_lambda_function" "get_expenses" {
  filename         = "../../expensify-backend-app/dist/expenses.zip"
  source_code_hash = filebase64sha256("../../expensify-backend-app/dist/expenses.zip")

  function_name = "get-expenses"
  handler       = "./src/handlers/expense/get-expenses.handler"

  role = aws_iam_role.expenses_lambda_role.arn

  runtime = "nodejs12.x"
}

#
# Permissions
#
resource "aws_iam_role" "expenses_lambda_role" {
  name               = "expenses_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_logs_policy" {
  role       = aws_iam_role.expenses_lambda_role.name
  policy_arn = aws_iam_policy.write_to_cloudwatch.arn
}

resource "aws_iam_policy" "write_to_cloudwatch" {
  name        = "write_to_cloudwatch"
  description = "Allows logs to be written to cloudwatch"
  policy      = data.aws_iam_policy_document.write_to_cloudwatch.json
}

data "aws_iam_policy_document" "write_to_cloudwatch" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    effect = "Allow"

    resources = [
      "*"
    ]
  }
}

