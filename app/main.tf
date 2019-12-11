provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
    source = "modules/vpc"
}
resource "aws_key_pair" "key_pair" {
  key_name   = "terraform-key"
  public_key = "~/.ssh/terraform-aws.pub"

resource "aws_instance" "webA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags = {
        Name = "webA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = module.vpc.aws_subnet_web1_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.WebserverSG.id]
}
resource "aws_instance" "webB" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "webB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = module.vpc.aws_subnet_web2_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.WebserverSG.id]
}
resource "aws_instance" "bastionA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "bastionA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = module.vpc.aws_subnet_web1_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.bastionhostSG.id]
}

resource "aws_instance" "bastoionB" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "bastionB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = module.vpc.aws_subnet_web2_id
    key_name = aws_key_pair.keypair.key_name
    vpc_security_group_ids = [aws_security_group.bastionhostSG.id]
}

resource "aws_elb" "lb" {
    name_prefix = "${var.name}-lb"
    subnets = [module.vpc.aws_subnet_web1_id, module.vpc.aws_subnet_web2_id]
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "80/"
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
    security_groups = [aws_security_group.LoadBalancerSG.id]
}