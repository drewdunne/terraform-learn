resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-default-sg"
    }
}

module "myapp-subnet" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp-vpc.id
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
}
# Retrieve the correct AMI
data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["137112412989"] #amazon
    filter {
        name = "name" #what are we filtering
        values = ["amzn2-ami-kernel-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = module.myapp-subnet.subnet.id #'subnet' is the exported value in /modules/subnet/outputs.tf
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    # user_data = file("/Users/andrewdunne/repos/terraform/myapp-server-user-data.sh")
    user_data_replace_on_change = true

    tags = {
        Name = "${var.env_prefix}-server"
    }
}

resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.public_key_location)
}



