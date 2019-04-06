resource "aws_security_group" "mnist_model" {
  name        = "mnist_model"
  description = "Allow inbound traffic"
  vpc_id      = "${module.vpc.vpc_id}"

  # The model is using 8500 ports
  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    # The only people that can communicate with this are
    # instances within the security group and instances of the API
    security_groups = ["${aws_security_group.mnist_model.id}",
                       "${aws_security_group.mnist_allow_http.id}"]
  }

  # Allow access to anywhere
  # any port, to any port and can be any protocol
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

#####################################################################
# MNIST Module Autoscaling group with external launch configuration #
#####################################################################

resource "aws_launch_configuration" "model-lc" {
  name_prefix = "MNIST-model-lc-"
  image_id = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  şecurity_groups = ["${aws_security_group.mnist_model.id}"]

  lifecycle {
    create_before_destroy = true
  }

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.pvt_key)}"
  }

  provisioner "file" {
    source      = "C:\\Users\\Roman\\code\\Styria-Mnist-Demo\\model_execution_scripts"
    destination = "~/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/model_execution_scripts/docker_setup_model.sh",
      "cd ~/model_execution_scripts",
      "sudo ~/model_execution_scripts/docker_setup_model.sh || ~/model_execution_scripts/docker_setup_model.sh ",
    ]
  }
}

module "model-asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "MNIST-model-autoscaling"

  # Launch configuration
  launch_configuration = "${aws_launch_configuration.model-lc.name}"
  create_lc = false

  # Add instances to load balancer
  load_balancers = ["${module.this_elb_id}"]

  root_block_device = [
    {
      # 200 GB root partition, general purpose SSD
      volume_size = "200"
      volume_type = "gp2"
    },
  ]

  # At least 200 GB for production because of I/O speed
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "${terraform.workspace == "production" ? 200 : 50}"
      delete_on_termination = true
    },
  ]

  # Autoscaling group

  asg_name = "MNIST-model-asg"
  vpc_zone_identifier = ["${module.vpc.private_subnets}"]
  min_size = 1
  desired_capacity = 1
  max_size = 3
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
