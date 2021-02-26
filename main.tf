provider "aws" {
   access_key = var.access_key
   secret_key = var.secret_key
   region = var.region
}
#-----------------------------------------------------------
resource "aws_instance" "test_server_master" {
        ami = var.ami
        instance_type = var.instance_type
        subnet_id = aws_subnet.my_VPC_Subnet.id
        vpc_security_group_ids = [aws_security_group.sg_lemp.id]
	      key_name = var.key_name
        associate_public_ip_address = true
        tags = {
        Name = "lemp_${var.projectName}"
        }
        depends_on = [aws_instance.test_server_wireguard]
        provisioner "local-exec" {
          command = <<EOD
          cat <<EOF > hosts.txt
[linux1]
linux1  ansible_host=${self.public_ip} ansible_user=ubuntu    ansible_ssh_private_key_file=~/Downloads/oleh-pet-project-key.pem
EOF
EOD

}
}
#-----------------------------------------------------------
resource "aws_instance" "test_server_wireguard" {
        ami = var.ami
        instance_type = var.instance_type
        subnet_id = aws_subnet.my_VPC_Subnet.id
        vpc_security_group_ids = [aws_security_group.sg_wireguard.id]
	      key_name = var.key_name
        associate_public_ip_address = true
        tags = {
        Name = "wireguard_${var.projectName}"
        }
#        depends_on = [aws_instance.test_server_master]
        provisioner "local-exec" {
          command = <<EOD
          cat <<EOF >> hosts.txt
[server]
server-1 ansible_ssh_host=${self.public_ip} vpn_ip=192.168.0.1 ansible_user=ubuntu  ansible_ssh_private_key_file=~/Downloads/oleh-pet-project-key.pem  public_ip=${self.public_ip}
client  public_ip=${self.public_ip} wireguard_public_key=CLzi36GfXTX7H0+LZs8wogx0jZeOczGMhfkHTbxZhGw=

[vpn-servers]
server-1
client

[linux1:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
EOD

}
}
#-----------------------------------------------------------
resource "aws_vpc" "my_VPC" {
  cidr_block           = var.vpcCIDRblock
  tags = {
    Name = "${var.projectName}_vpc"
  }
}
#-----------------------------------------------------------
resource "aws_subnet" "my_VPC_Subnet" {
  vpc_id                  = aws_vpc.my_VPC.id
  cidr_block              = var.subnetCIDRblock
  tags = {
    Name = "${var.projectName}_subnet"
  }
}
#-----------------------------------------------------------
resource "aws_security_group" "sg_lemp" {
          name        = "${var.projectName}_SG_lemp"
          vpc_id = aws_vpc.my_VPC.id
          depends_on = [aws_instance.test_server_wireguard]

  dynamic "ingress"{
      for_each = ["80", "443"]
      content {
              from_port = ingress.value
              to_port = ingress.value
              protocol = "tcp"
              cidr_blocks = [var.CIDRblock]
           }
          }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_instance.test_server_wireguard.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.CIDRblock]
  }
}
#-----------------------------------------------------------
resource "aws_security_group" "sg_wireguard" {
          name        = "${var.projectName}_SG_wireguard"
          vpc_id = aws_vpc.my_VPC.id

  dynamic "ingress"{
      for_each = ["22", "80", "443", "51820"]
      content {
              from_port = ingress.value
              to_port = ingress.value
              protocol = "tcp"
              cidr_blocks = [var.CIDRblock]
           }
          }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.CIDRblock]
  }
}
#-----------------------------------------------------------
resource "aws_internet_gateway" "my_VPC_GW" {
 vpc_id = aws_vpc.my_VPC.id
 tags = {
        Name = "${var.projectName}_GW"
}
}
#-----------------------------------------------------------
resource "aws_route_table" "my_VPC_route_table" {
 vpc_id = aws_vpc.my_VPC.id
 tags = {
        Name = "${var.projectName}_route_table"
}
}
#-----------------------------------------------------------
resource "aws_route" "My_VPC_internet_access" {
  route_table_id         = aws_route_table.my_VPC_route_table.id
  destination_cidr_block = var.destinationCIDRblock
  gateway_id             = aws_internet_gateway.my_VPC_GW.id
}
#-----------------------------------------------------------
resource "aws_route_table_association" "My_VPC_association" {
  subnet_id      = aws_subnet.my_VPC_Subnet.id
  route_table_id = aws_route_table.my_VPC_route_table.id
}
#-----------------------------------------------------------
output "done" {
  value = var.done
}
