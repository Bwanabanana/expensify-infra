terraform {
 backend "s3" {
   encrypt        = true
   bucket         = "bwanabanana-terraform-state"
   dynamodb_table = "bwanabanana-terraform-state-lock"
   region         = "eu-west-2"
   key            = "expensify-frontend"
 }
}
