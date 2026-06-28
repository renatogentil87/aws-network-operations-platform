# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Prevent accidental deletion of the lock table
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = var.lock_table_name
  }
}
