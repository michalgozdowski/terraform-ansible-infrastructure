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
resource "aws_instance" "bastionA" {
    ami = "ami-0cc0a36f626a4fdf5"
    instance_type = "t2.micro"
    tags = {
        Name = "bastionA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = data.terraform_remote_state.vpc.outputs.aws_subnet_web1_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.BASsecuritygroup.id]
}

resource "aws_instance" "bastoionB" {
    ami = "ami-0cc0a36f626a4fdf5"
    instance_type = "t2.micro"
    tags = {
        Name = "bastionB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = data.terraform_remote_state.vpc.outputs.aws_subnet_web2_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.BASsecuritygroup.id]
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

    egress {
        from_port = 80
        to_port = 80
        protocol = "TCP"
        security_groups = ["${aws_security_group.WEBsecuritygroup.id}"]
    }

    egress {
        from_port = 443
        to_port = 443
        protocol = "TCP"
        security_groups = ["${aws_security_group.WEBsecuritygroup.id}"]
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
        security_groups = ["${aws_security_group.BASsecuritygroup.id}"]
        description = "Allow incoming SSH traffic from Bastion Host"
    }
  ingress {
      from_port = -1
      to_port = -1
      protocol = "ICMP"
      security_groups = ["${aws_security_group.BASsecuritygroup.id}"]
      description = "Allow incoming ICMP from management IPs"
  }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }
    egress {
        from_port = 3128
        to_port = 3128
        protocol = "TCP"
        security_groups = ["${aws_security_group.BASsecuritygroup.id}"]
    }
    tags = {
        Name = "WebServer-securitygroup"
    }
}

resource "aws_security_group" "BASsecuritygroup" {
  name = "BASsecuritygroup"
  vpc_id = data.terraform_remote_state.vpc.outputs.aws_vpc_id
  description = "Security group for bastion hosts"
  ingress {
      from_port = 22
      to_port = 22
      protocol = "TCP"
      cidr_blocks = var.mgmt_ips
      description = "Allow incoming SSH from management IPs"
  }

  ingress {
      from_port = -1
      to_port = -1
      protocol = "ICMP"
      cidr_blocks = var.mgmt_ips
      description = "Allow incoming ICMP from management IPs"
  }
  egress {
      from_port = 0
      to_port = 0
      cidr_blocks = ["0.0.0.0/0"]
      protocol = "-1"
      description = "Allow all outgoing traffic"
  }
  tags = {
      Name = "Bastion-securitygroup"
  }
}

resource "aws_security_group_rule" "LBaccess" {
    security_group_id = "${aws_security_group.WEBsecuritygroup.id}"
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "TCP"
    source_security_group_id = "${aws_security_group.LBsecuritygroup.id}"
    description = "Allow Squid proxy access from loadbalancers"
}

resource "aws_security_group_rule" "LBaccess2" {
    security_group_id = "${aws_security_group.WEBsecuritygroup.id}"
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "TCP"
    source_security_group_id = "${aws_security_group.LBsecuritygroup.id}"
    description = "Allow Squid proxy access from loadbalancers"
}

resource "aws_security_group_rule" "PROXYaccess" {
    security_group_id = "${aws_security_group.BASsecuritygroup.id}"
    type = "ingress"
    from_port = 3128
    to_port = 3128
    protocol = "TCP"
    source_security_group_id = "${aws_security_group.WEBsecuritygroup.id}"
    description = "Allow Squid proxy access from webservers"
}

