resource "aws_instance" "webA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags = {
        Name = "webA-${var.name}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.pub-web-az-a.id}"
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
    subnet_id = "${aws_subnet.pub-web-az-b.id}"
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
    subnet_id = "${aws_subnet.pub-web-az-a.id}"
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
    subnet_id = "${aws_subnet.pub-web-az-b.id}"
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