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
    # instances within the security group
    security_groups = ["${aws_security_group.mnist_model.id}"]
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

##############
# MNIST Module
##############

# Use the AWS Database module
resource "aws_instance" "mnist_model" {

  image_id        = "ami-059eeca93cf09eebd"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.mnist_model.id}"]

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
      "chmod +x ~/proj/setup_docker_model.sh",
      "sudo ~/proj/setup_docker_model.sh",
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
  vpc_zone_identifier       = ["${module.vpc.private_subnets}"]
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
