
provider "aws" {
    region = "eu-west-1"
}

resource "aws_instance" "example" {
ami = "ami-0bf84c42e04519c85" 
instance_type = "t2.micro" 
vpc_security_group_ids = [aws_security_group.instance.id]

user_data = <<-EOF
            #!/bin/bash
            sudo yum install -y httpd
            sudo service httpd start
            cd /var/www/
            sudo chmod 777 html
            cd html/
            sudo echo "Hello, World" > index.html
            sudo systemctl status httpd
            EOF

tags={
  Name = "terraform-example"
  } 
}

resource "aws_security_group" "instance" { 
    name = "terraform-example-instance"
    ingress {
      from_port = 10
      to_port = 8080
      protocol = "tcp" 
      cidr_blocks = ["0.0.0.0/0"]
  } 
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1" 
      cidr_blocks = ["0.0.0.0/0"]
  } 
}

variable "server_port" {
  description = "The port the server will use for HTTP requests" 
  type = number
  default = 80
}


#resource "<PROVIDER>_<TYPE>" "<NAME>" { [CONFIG ...] }

#resource "aws_instance" "example" {
#  ami = "ami-0c55b159cbfafe1f0" 
#  instance_type = "t2.micro"
#}


# https://aws.amazon.com/ec2/instance-types/ - All Instance types 

# https://aws.amazon.com/marketplace/search/results?searchTerms=ami&PRICING_MODEL=FREE&REGION=eu-west-1&filters=PRICING_MODEL%2CREGION - MarketPlace AMIs

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance - Terraform documentation

#For example, instead of having to manually poke around the EC2 console to find the IP address of your server, you can provide the IP address as an output variable:
#    output "public_ip" {
#      value       = aws_instance.example.public_ip
#      description = "The public IP address of the web server"
#}
#$ terraform output public_ip
#    54.174.13.5

output "alb_dns_name" {
      value       = aws_lb.example.dns_name
      description = "The domain name of the load balancer"
}

#################################
# Auto-Scalling config 

resource "aws_launch_configuration" "example" { 
    image_id = "ami-0bf84c42e04519c85" 
    instance_type ="t2.micro"
    security_groups = [aws_security_group.instance.id]

user_data = <<-EOF
            #!/bin/bash
            sudo yum install -y httpd
            sudo service httpd start
            cd /var/www/
            sudo chmod 777 html
            cd html/
            sudo echo "Hello, World" > index.html
            sudo systemctl status httpd
            EOF

# Required when using a launch configuration with an auto scaling group. # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
lifecycle {
  create_before_destroy = true 
  }
}


#A data source represents a piece of read-only information that is fetched from the provider (in this case, AWS) every time you run Terraform.
#For example, the AWS provider includes data sources to look up VPC data, subnet data, AMI IDs, IP address ranges, the current user’s identity, and much more.
#data "<PROVIDER>_<TYPE>" "<NAME>" {
#      [CONFIG ...]
#}
data "aws_vpc" "default" { 
    default = true
}

data "aws_subnet_ids" "default" { 
    vpc_id = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "example" { 
    
      launch_configuration = aws_launch_configuration.example.name
      vpc_zone_identifier = data.aws_subnet_ids.default.ids

      target_group_arns = [aws_lb_target_group.asg.arn]
      health_check_type = "ELB"

      min_size = 2
      max_size = 10

      tag {
        key = "Name"
        value = "terraform-asg-example" 
        propagate_at_launch = true
   } 
}


#################################
#Load Balancer setup. The first step is to create the ALB itself using the aws_lb resource:
#You’ll need to tell the aws_lb resource to use this security group via the security_groups argument:

resource "aws_lb" "example" {
  name = "terraform-asg-example" 
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default.ids
  security_groups = [aws_security_group.alb.id]
}

#This security group should allow incoming requests on port 80 so that you can access the load balancer over HTTP, and outgoing requests on all ports so that the load bal‐ ancer can perform health checks:

resource "aws_security_group" "alb" { 
    name = "terraform-example-alb"

    # Allow inbound HTTP requests
    ingress {
      from_port   =80
      to_port     = 8080
      protocol    = "tcp" 
      cidr_blocks = ["0.0.0.0/0"]
}
    # Allow all outbound requests
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1" 
      cidr_blocks = ["0.0.0.0/0"]
  } 
}

#The next step is to define a listener for this ALB using the aws_lb_listener resource:

resource "aws_lb_listener" "http" {     
    load_balancer_arn = aws_lb.example.arn 
    port = 80
protocol = "HTTP"
# By default, return a simple 404 page
      default_action {
        type = "fixed-response"
        fixed_response {
          content_type = "text/plain"
          message_body = "404: page not found"
          status_code  = 404
    } 
  }
}

#Next, you need to create a target group for your ASG using the aws_lb_target_group resource:


resource "aws_lb_target_group" "asg" { 
    name = "terraform-asg-example" 
    port = var.server_port
    protocol = "HTTP"
    vpc_id =data.aws_vpc.default.id
      health_check {
        path                = "/"    
        protocol            = "HTTP"
        matcher             = "200" 
        interval            = 15
        timeout             = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
  } 
}

#Finally, it’s time to tie all these pieces together by creating listener rules using the aws_lb_listener_rule resource:

resource "aws_lb_listener_rule" "asg" { 
    listener_arn = aws_lb_listener.http.arn 
    priority     = 100

    condition {
      path_pattern {
        values = ["/static/*"]
      }
    }

      action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    } 
}


##################################################################