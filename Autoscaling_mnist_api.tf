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
    security_groups = ["${aws_security_group.mnist_model.id}"
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

##################################################################
# MNIST API Autoscaling group with external launch configuration #
##################################################################

resource "aws_launch_configuration" "api-lc" {
  name_prefix     = "MNIST-model-lc-"
  image_id        = "${data.aws_ami.amazon_linux.id}"
  instance_type   = "t2.micro"
  şecurity_groups = ["${aws_security_group.mnist_model.id}", "${aws_security_group.mnist_allow_http.id}"]

  lifecycle {
    create_before_destroy = true
  }

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.pvt_key)}"
  }

# Copy the entire frontend folder into the home directory 
# of the user that is logged in: home/ubuntu/ in this case
  provisioner "file" {
    source      = "~/api_execution_scripts"
    destination = "~/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/api_execution_scripts/setup_docker_api.sh",
      "sudo ~/api_execution_scripts/setup_docker_api.sh",
    ]
  }
}

# Use the templating module for autoscaling
module "api-asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "MNIST-api-autoscaling"

  # Launch configuration
  launch_configuration = "${aws_launch_configuration.model-lc.name}"
  create_lc = false
  
  # when new instances are created it's going to get added to that load balancer
  load_balancers  = ["${module.elb.this_elb_id}"]

  # At least 200 GB for production because of I/O speed
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "${terraform.workspace == "production" ? 200 : 50}"
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

  asg_name                  = "MNIST-api-asg"
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
      value               = "${terraform.workspace}"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]
}
