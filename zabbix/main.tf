# create aws instances over terraform


provider "aws" {
  region = "eu-north-1"
}

data "aws_ami" "ami_lat_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.*-amd64-server-20*"]
  }
}

resource "aws_instance" "zabbix_server" {
  count                  = 1
  ami                    = data.aws_ami.ami_lat_ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.zabbix_sg.id]
  key_name               = "igoz-keys-stockholm"
  user_data              = file("user_data.sh")
  tags = {
    Name = "zabbix-server №${count.index + 1}"
  }
}



resource "aws_security_group" "zabbix_sg" {
  name        = "zabbix_sg"
  description = "zabbix_sg"

  dynamic "ingress" {
    for_each = ["22", "80", "443"]
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "zabbix_sg"
  }
}


output "public_ip_zabbix_server_1" {
  value = aws_instance.zabbix_server[0].public_ip
}

