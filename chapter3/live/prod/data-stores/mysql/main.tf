provider "aws" { 
    region = "eu-west-1"
}

module "webserver_cluster" {
source = "../../../modules/services/webserver-cluster"
cluster_name           = "webservers-stage"
      db_remote_state_bucket = "terraform-up-and-running-state-eu-west-1-test-state-gtsvetkov"
      db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

      instance_type = "t2.micro"
      min_size      = 2
      max_size      = 2

}


resource "aws_db_instance" "example" {
  identifier_prefix = "terraform-up-and-running"
  engine            = "mysql"
  allocated_storage = 10
  instance_class    = "db.t2.micro"
  name              = "example_database"
  username          = "admin"

  # How should we set the password? You could use the AWS Secrets Manager UI to store the secret and then read the secret back out in your Terraform code using the aws_secretsman ager_secret_version data source:

  password = "1234567890" #data.aws_secretsmanager_secret_version.db_password.secret_string

}
