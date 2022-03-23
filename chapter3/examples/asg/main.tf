provider "aws" {
  region = "eu-west-1"
}

module "asg" {
  source             = "../../modules/cluster/asg-rolling-deploy"
  cluster_name       = "xampleTest"
  ami                = "ami-0bf84c42e04519c85"
  instance_type      = "t2.micro"
  min_size           = 1
  max_size           = 1
  enable_autoscaling = false
  subnet_ids         = data.aws_subnet_ids.default.ids
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}