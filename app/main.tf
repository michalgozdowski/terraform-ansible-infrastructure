terraform {
  backend "s3" {
    bucket         = "terraform-state-galanonymous"
    key            = "global/s3/app/terraform.tfstate"
    region         = "eu-central-1"  
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
data "terraform_remote_state" "vpc" {
 backend     = "s3" 
 config = {
   bucket = "terraform-state-galanonymous"
   key    = "global/s3/terraform.tfstate"
   region = "eu-central-1"
 }
}
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_key_pair" "keypair" {
  key_name = "terraform-key"
  public_key = "${file("~/.ssh/terraform_key.pub")}"
}

resource "aws_instance" "webA" {
    ami = "ami-0cc0a36f626a4fdf5"
    instance_type = "t2.micro"
    tags = {
        Name = "webA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = data.terraform_remote_state.vpc.outputs.aws_subnet_web1_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.WEBsecuritygroup.id]
}
resource "aws_instance" "webB" {
    ami = "ami-0cc0a36f626a4fdf5"
    instance_type = "t2.micro"
    tags = {
        Name = "webB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = data.terraform_remote_state.vpc.outputs.aws_subnet_web2_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.WEBsecuritygroup.id]
}

resource "aws_elb" "lb" {
    name_prefix = "${var.name}lb"
    subnets = [data.terraform_remote_state.vpc.outputs.aws_subnet_web1_id, data.terraform_remote_state.vpc.outputs.aws_subnet_web2_id]
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/"
        interval = 30
    }
    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
    listener {
        instance_port = 443
        instance_protocol = "https"
        lb_port = 443
        lb_protocol = "https"
    }
    listener {
        instance_port = 22
        instance_protocol = "tcp"
        lb_port = 22
        lb_protocol = "tcp"
    }
    cross_zone_load_balancing = true
    instances = [aws_instance.webA.id, aws_instance.webB.id]
    security_groups = [aws_security_group.LBsecuritygroup.id]
}

resource "aws_security_group" "LBsecuritygroup" {
    name = "LBsecuritygroup"
    vpc_id = data.terraform_remote_state.vpc.outputs.aws_vpc_id
    description = "Security group for load-balancers"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow incoming HTTP traffic from anywhere"
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow incoming HTTPS traffic from anywhere"
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
        description = "Allow incoming SSH traffic from my IP only"
    }
    tags = {
        Name = "LB-securitygroup"
    }
}

resource "aws_security_group" "WEBsecuritygroup" {
    name = "WEBsecuritygroup"
    vpc_id = data.terraform_remote_state.vpc.outputs.aws_vpc_id
    description = "Security group for webservers"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        security_groups = ["${aws_security_group.LBsecuritygroup.id}"]
        description = "Allow incoming SSH traffic from Load Balancer"
    }
    ingress {
      from_port = -1
      to_port = -1
      protocol = "ICMP"
      security_groups = ["${aws_security_group.LBsecuritygroup.id}"]
      description = "Allow incoming ICMP from management IPs"
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }
    tags = {
        Name = "WebServer-securitygroup"
    }
}

resource "aws_security_group_rule" "allowHTTP" {
  type            = "egress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_group_id = aws_security_group.LBsecuritygroup.id

}

resource "aws_security_group_rule" "allowHTTPS" {
  type            = "egress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  security_group_id = aws_security_group.LBsecuritygroup.id
}

resource "aws_security_group_rule" "allowSSH" {
  type            = "egress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_group_id = aws_security_group.LBsecuritygroup.id

}

resource "aws_security_group_rule" "WEBallowSSH" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_group_id = aws_security_group.WEBsecuritygroup.id
  source_security_group_id = aws_security_group.LBsecuritygroup.id
}

resource "aws_security_group_rule" "WEBallowHTTP" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_group_id = aws_security_group.WEBsecuritygroup.id
  source_security_group_id = aws_security_group.LBsecuritygroup.id
}

resource "aws_security_group_rule" "WEBallowHTTPS" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  security_group_id = aws_security_group.WEBsecuritygroup.id
  source_security_group_id = aws_security_group.LBsecuritygroup.id
}