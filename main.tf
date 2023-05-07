provider "aws" {
    region = "us-east-2"
  
}

resource "aws_instance" "testec2" {
    ami = "ami-0a695f0d95cefc163"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
    tags = {
        Name = "Terraform-example"
    }
  
}
resource "aws_security_group" "instance" {
  name = "Terraform-Example-sg"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "Alb" {
    name = "terraform-example-Albsg"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
        
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = [ "0.0.0.0/0" ]       
    }
}
resource "aws_launch_configuration" "wisegp" {
    image_id = "ami-0a695f0d95cefc163"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF 
    lifecycle {
      create_before_destroy = true
    }
}
resource "aws_autoscaling_group" "wiseasg" {
    launch_configuration = aws_launch_configuration.wisegp.name
    vpc_zone_identifier = data.aws_subnets.default.ids
    target_group_arns = [aws_alb_target_group.albtg.arn]
    min_size = 2
    max_size = 10
    tag {
      key = "Name"
      value = "Terraform-ASG-Example"
      propagate_at_launch = true

    }
  
}
resource "aws_lb" "wiselb" {
    name = "Terraform-ASG-Example"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.Alb.id]
  
}
resource "aws_lb_listener" "HTTP" {
    load_balancer_arn = aws_lb.wiselb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      type = "fixed-response"
      fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
      }

    }
}
resource "aws_lb_listener_rule" "ASG" {
    listener_arn = aws_lb_listener.HTTP.arn
    priority = 100
    condition {
      path_pattern {
        values = [ "*" ]
      }
    }
  action {
    type = "forward"
    target_group_arn = aws_alb_target_group.albtg.arn
  }
}
resource "aws_alb_target_group" "albtg" {
    name = "Terraform-Example-ASG"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    } 
}


