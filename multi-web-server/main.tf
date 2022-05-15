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

# Create a VPC to launch instances into
resource "aws_vpc" "ws_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway for subnets
resource "aws_internet_gateway" "ws_gateway" {
  vpc_id = aws_vpc.ws_vpc.id
}

# Grant the VPC internet access on its main route table.
resource "aws_route" "route" {
  route_table_id         = aws_vpc.ws_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ws_gateway.id
}

# Create subnets in each availability zone
resource "aws_subnet" "main" {
  count                   = length(data.aws_availability_zones.ws-az.names)
  vpc_id                  = aws_vpc.ws_vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.ws-az.names, count.index)
}

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

  desired_capacity    = lookup(var.scalefactor, "desired_capacity")
  min_size            = lookup(var.scalefactor, "min_size")
  max_size            = lookup(var.scalefactor, "max_size")
  vpc_zone_identifier = aws_subnet.main.*.id

  launch_template {
    id      = aws_launch_template.ws_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "Webserver"
    propagate_at_launch = true
  }
}

# Application load balancer
resource "aws_lb" "ws-elb" {
  name = "ws-elb"

  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb-sg.id]
  subnets            = aws_subnet.main.*.id

  tags = {
    Environment = "Production"
    Role        = "Webserver"
  }
}

# Load Balancer target group
resource "aws_lb_target_group" "ws_elb_target" {
  name = "ws-elb-target-group"

  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ws_vpc.id

  health_check {
    unhealthy_threshold = lookup(var.health_check, "unhealthy_threshold")
    timeout             = lookup(var.health_check, "timeout")
    interval            = lookup(var.health_check, "interval")
    path                = lookup(var.health_check, "path")
    port                = lookup(var.health_check, "port")
  }
}

# Load Balancer Listener for HTTP
resource "aws_lb_listener" "ws_elb_listener_http" {
  load_balancer_arn = aws_lb.ws-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ws_elb_target.arn
  }
}

# Register AG instances as target
resource "aws_autoscaling_attachment" "ws_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ws-asg.id
  lb_target_group_arn    = aws_lb_target_group.ws_elb_target.arn
}

# Security group used by application load balancer
resource "aws_security_group" "elb-sg" {
  name        = "elb-sg"
  description = "Terraform webserver load balancer security group"
  vpc_id      = aws_vpc.ws_vpc.id

  dynamic "ingress" {
    for_each = var.allow_ingress_elb
    content {
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      protocol         = "TCP"
      from_port        = ingress.value
      to_port          = ingress.value
    }
  }

  egress {
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
  }
}

# Security group used by EC2 instance in the ASG
resource "aws_security_group" "ec2-sg" {
  name        = "ec2-sg"
  description = "Terraform webserver ec2 instances security group"
  vpc_id      = aws_vpc.ws_vpc.id

  dynamic "ingress" {
    for_each = var.allow_ingress_elb
    content {
      security_groups = [aws_security_group.elb-sg.id]
      protocol        = "TCP"
      from_port       = ingress.value
      to_port         = ingress.value
    }
  }

  ingress {
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    from_port        = 22
    to_port          = 22
  }

  egress {
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
  }
}

