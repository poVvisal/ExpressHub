terraform {
  backend "s3" {
    bucket         = "expresshub-tfstate-v1" # Or whatever you named it if that was taken!
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "expresshub-state-lock"
    encrypt        = true
  }
}
