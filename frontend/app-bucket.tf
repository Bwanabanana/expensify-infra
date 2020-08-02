
#
# app distribution bucket
#
resource "aws_s3_bucket" "app_bucket" {

  bucket = format("%s.%s", var.app_name, var.domain_name)

  logging {
    target_bucket = aws_s3_bucket.logs_bucket.id
    target_prefix = "s3/access"
  }

  website {
    index_document = "index.html"
  }
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE", "PUT", "HEAD"]
    allowed_origins = ["*"]
  }
}

#
# app distribution bucket policy
#
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.id
  policy = data.aws_iam_policy_document.app_bucket_iam_policy_document.json
}

data "aws_iam_policy_document" "app_bucket_iam_policy_document" {

 statement {
    actions   = ["s3:GetObject"]
    resources = [format("%s/*", aws_s3_bucket.app_bucket.arn)]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:UserAgent"
      values   = [var.cloud_front_access_secret]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app_bucket.arn]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_user.WebSiteLoader.arn]
    }
  }

  statement {
    actions   = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject"]
    resources = [format("%s/*", aws_s3_bucket.app_bucket.arn)]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_user.WebSiteLoader.arn]
    }
  }
}

data "aws_iam_user" "WebSiteLoader" {
  user_name = "WebSiteLoader"
}
