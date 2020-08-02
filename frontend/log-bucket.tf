
#
# logging bucket
#
resource "aws_s3_bucket" "logs_bucket" {
  bucket = format("%s.%s-logs", var.app_name, var.domain_name)
  acl    = "log-delivery-write"
}
