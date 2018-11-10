# Create access to our web cluster
resource "aws_security_group" "mnist_allow_http" {
  name        = "mnist_allow_http"
  description = "Allow inbound traffic"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################
# Data source to get AMI details
################################

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

######
# Launch configuration and autoscaling group
######

# Use the templating module for autoscaling
module "styria_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "styria example"

  # Launch configuration
  #
  # launch_configuration = "my-existing-launch-configuration" # Use the existing launch configuration
  # create_lc = false # disables creation of launch configuration
  # Name the launch configuration
  lc_name = "styria-lc"

  #image_id        = "${data.aws_ami.amazon_linux.id}"
  # or we can use a base image for ubuntu 16.04:
  image_id        = "ami-059eeca93cf09eebd"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.mnist_allow_http.id}"]
  # when new instances are created it's going to get added to that load balancer
  load_balancers  = ["${module.elb.this_elb_id}"]

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.pvt_key)}"
  }

# Copy the entire frontend folder into the home directory 
# of the user that is logged in: home/ubuntu/ in this case
  provisioner "file" {
    source      = "~/proj"
    destination = "~/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/proj/setup_docker_api.sh",
      "sudo ~/proj/setup_docker_api.sh",
    ]
  }

  # At least 200 GB for production because of I/O speed
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "200"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      # 200 GB root partition, general purpose SSD
      volume_size = "200"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = "styria-asg"
  # Pull the list of public subnets from the VPC module
  vpc_zone_identifier       = ["${module.vpc.public_subnets}"]
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 5
  desired_capacity          = 2
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = "Production"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]
}
