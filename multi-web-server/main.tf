### Data source ###
# AMI images
data "aws_ami" "ubuntu" {
  most_recent = true             # Fetch the latest image
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-*-amd64-server-*"]
  }
}

# Availability zones
data "aws_availability_zones" "ws-az" {
  all_availability_zones = true
}

### Webserver resources ###
# Launch template for each EC2 configuration

resource "aws_launch_template" "ws_template" {
  name = "ws-template"

  instance_type          = var.instance_type
  image_id               = data.aws_ami.ubuntu.id
  vpc_security_group_ids = [aws_security_group.ec2-sg.id]
  key_name               = var.keyname

  user_data = filebase64("user-data.sh")
}

# Auto Scaling Group 
resource "aws_autoscaling_group" "ws-asg" {
  name = "ws-asg"

  desired_capacity   = lookup(var.scalefactor, "desired_capacity")
  min_size           = lookup(var.scalefactor, "min_size")
  max_size           = lookup(var.scalefactor, "max_size")
  availability_zones = data.aws_availability_zones.ws-az.names

  launch_template {
    id      = aws_launch_template.ws_template.id
    version = "$Latest"
  }
}

# Application load balancer
resource "aws_lb" "ws-elb" {
  name = "ws-elb"

  internal = filebase64
  load_balancer_type = "application"
  security_groups = [aws_security_group.elb-sg.id]
  subnets = [for subnet in aws_subnet.public : subnet.id]
}


# Security group used by application load balancer
resource "aws_security_group" "elb-sg" {
  name = "elb-sg"

  dynamic "ingress" {
    for_each = var.allow_ingress_elb
    content {
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      protocol    = "TCP"
      from_port   = ingress.value
      to_port     = ingress.value
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}


# Security group used by EC2 instance in the ASG
resource "aws_security_group" "ec2-sg" {
  name = "ec2-sg"

  ingress {
    security_groups = [aws_security_group.elb-sg.id]
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol    = "TCP"
    from_port   = 22
    to_port     = 22
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

