terraform {
  backend "s3" {
    bucket         = "aws-netops-platform-tfstate"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-netops-platform-tfstate-lock"
    encrypt        = true
  }
}
