locals {
# The office-ips below are set to the GDS office egress ips, this local var is used to whitelist inbound ssh connections
  office-ips = [
    "85.133.67.244/32",
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
  ]
}

resource "aws_vpc" "cyber-security-nessus" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name      = "Cyber Security Nessus VPC"
    ManagedBy = "terraform"
  }
}

resource "aws_internet_gateway" "cyber-security-nessus-igw" {
  vpc_id = "${aws_vpc.cyber-security-nessus.id}"

  tags = {
    Name      = "Cyber Security Nessus Internet Gateway"
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "cyber-security-nessus-subnet" {
  vpc_id     = "${aws_vpc.cyber-security-nessus.id}"
  cidr_block = "10.1.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "Cyber Security Nessus Subnet in London AZ a"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table" "cyber-security-nessus-route-table" {
  vpc_id = "${aws_vpc.cyber-security-nessus.id}"

  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.cyber-security-nessus-igw.id}"
  }

  tags = {
    Name      = "Cyber Security Nessus Routing Table"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "cyber-security-nessus-association" {
  subnet_id      = "${aws_subnet.cyber-security-nessus-subnet.id}"
  route_table_id = "${aws_route_table.cyber-security-nessus-route-table.id}"
}

data "aws_ami" "cyber-security-nessus-ami" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "product-code"
    values = ["8fn69npzmbzcs4blc4583jd0y"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "nessus_userdata" {
  template = "${file("cloudinit/nessus_instance.yaml")}"

  vars = {
    hostname        = "nessus-01"
    bootstrap-tools = "${file("cloudinit/bootstrap-tools.sh.tpl")}"
  }
}

resource "aws_security_group" "nessus-sg" {
  name        = "nessus-sg"
  description = "Nessus Instance Security Group"
  vpc_id      = "${aws_vpc.cyber-security-nessus.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.office-ips
  }

  ingress {
    from_port   = 8834
    to_port     = 8834
    protocol    = "tcp"
    cidr_blocks = local.office-ips
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "Nessus Scanning Instance"
    ManagedBy = "terraform"
  }
}

resource "aws_key_pair" "nessus_sp" {
  key_name    = "nessus_sp"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCBbC41tcH/FBmZTsdWQsODQohdRMuV1eKR2UkXRMCch70oCAVgTJ5+E3kVj+osqpo2e3eoODKaNqj56I0ZE1a/uQDQ+7YS8K7TbYpj57BNKfKH/9qPToXdu3xdLNKpKbfhwhZO6mHvIUU9hxjrheVNheNbiiL4i9cRTk/2DhlAZ5g9DNQhFjnPG+AJppUIeB9hMozJolR0I9prXpO/ySrcSWNEqJLUI9M5wyKD5qvrDb/1tauGQXNdAogSYod4Tnvm6VCx5PEZwlg6i6dutkFM/0EF6igi6zsQ+JRYLF7cHMCVTKqNccbfjKca7QXc9JYIQw3mjHXGWMH3OCC2gf8H nessus_sp"
}

resource "aws_instance" "nessus_instance" {
  ami           = "${data.aws_ami.cyber-security-nessus-ami.id}"
  instance_type = "t3a.xlarge"
  user_data     = "${data.template_file.nessus_userdata.rendered}"
  monitoring    = "true"
  subnet_id     = "${aws_subnet.cyber-security-nessus-subnet.id}"

  vpc_security_group_ids = [
    "${aws_security_group.nessus-sg.id}",
  ]

  tags = {
    Name      = "Nessus Scanning Instance"
    ManagedBy = "terraform"
  }
}