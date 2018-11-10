######
# ELB
######

# Use the AWS Elastic Load Balancer module
module "elb" {
  source = "terraform-aws-modules/elb/aws"

  name = "elb-styria"

  # Associate the ELB with the same security group
  subnets         = ["${module.vpc.public_subnets}"]
  security_groups = ["${aws_security_group.mnist_allow_http.id}"]
  internal        = false

  # Place a listener on port 8080
  listener = [
    {
      instance_port     = "8080"
      instance_protocol = "HTTP"
      lb_port           = "8080"
      lb_protocol       = "HTTP"
    },
  ]

  # Check every 30s
  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  tags = {
    Owner       = "user"
    Environment = "Production"
  }
}
