terraform {
  backend "s3" {
    bucket         = "terraform-state-galanonymous"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-central-1"  
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

resource "aws_instance" "dbA" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "${var.environment}-SQL001"
        Environment = "${var.environment}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.priv-db-az-a.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.DBServerSG.id}"]
}

resource "aws_instance" "dbB" {
    ami = "${lookup(var.aws_ubuntu_awis,var.region)}"
    instance_type = "t2.micro"
    tags {
        Name = "${var.environment}-SQL002"
        Environment = "${var.environment}"
        sshUser = "ubuntu"
    }
    subnet_id = "${aws_subnet.priv-db-az-b.id}"
    key_name = "${aws_key_pair.keypair.key_name}"
    vpc_security_group_ids = ["${aws_security_group.DBServerSG.id}"]
}

resource "aws_security_group_rule" "DBaccess" {
    security_group_id = "${aws_security_group.bastionhostSG.id}"
    type = "ingress"
    from_port = 3128
    to_port = 3128
    protocol = "TCP"
    source_security_group_id = "${aws_security_group.DBServerSG.id}"
    description = "Allow Squid proxy access from database servers"
}

resource "aws_security_group" "DBsecuritygroup" {
    name = "DBServerSG"
    vpc_id = "${aws_vpc.robertverdam.id}"
    description = "Security group for database servers"
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "TCP"
        security_groups = ["${aws_security_group.WebserverSG.id}"]
        description = "Allow incoming MySQL traffic from webservers"
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        security_groups = ["${aws_security_group.bastionhostSG.id}"]
        description = "Allow incoming SSH traffic from Bastion Host"
    }
  ingress {
      from_port = -1
      to_port = -1
      protocol = "ICMP"
      security_groups = ["${aws_security_group.bastionhostSG.id}"]
      description = "Allow incoming ICMP from management IPs"
  }
    egress {
        from_port = 3128
        to_port = 3128
        protocol = "TCP"
        security_groups = ["${aws_security_group.bastionhostSG.id}"]
    }
    tags
    {
        Name = "SG-DBServer"
    }
}