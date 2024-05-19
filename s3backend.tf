terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-kjadex"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    #dynamodb_table = "your_dynamodb_table_name"  # Optional for state locking
  }
}