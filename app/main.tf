provider "aws" {
  region = "eu-central-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}

resource "aws_instance" "webA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags = {
        Name = "webA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.web1SUBNET.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.WebserverSG.id}"]
}
resource "aws_instance" "webB" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "webB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.web2SUBNET.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.WebserverSG.id}"]
}
resource "aws_instance" "bastionA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "bastionA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.web1SUBNET.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.bastionhostSG.id}"]
}

resource "aws_instance" "bastoionB" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "bastionB-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.web2SUBNET.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.bastionhostSG.id}"]
}

resource "aws_elb" "lb" {
    name_prefix = "${var.name}-lb"
    subnets = ["${aws_subnet.web1SUBNET.id}", "${aws_subnet.web2SUBNET.id}"]
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
    instances = ["${aws_instance.webA.id}", "${aws_instance.webB.id}"]
    security_groups = ["${aws_security_group.LoadBalancerSG.id}"]
}