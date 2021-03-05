#---------------Setting for remote_state---------------------
/*terraform {
     backend = "s3"
         bucket = "bucket-name"
         key = var.key
         region = var.region
         dynamodb_table = "dynamodb-terraform-state-lock"
         encrypt = true
}
*/
#-----------------------------------------------------------
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
#----------If you want static public_ip---------------------
# resource "aws_eip" "eip" {
#   instance = aws_instance.test_server_master.id
#   vpc      = true
# }

# output "public_ip" {
#   value = aws_instance.test_server_master.public_ip
# }
#---------------Setting for static site(e.g Wordpress)-------
# resource "aws_route53_zone" "dns_name_aws" {
#   name = "project-by-oleg.space"

#   tags = {
#     Environment = "prod"
#   }
# }

# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.dns_name_aws.zone_id
#   name    = "www.project-by-oleg.space"
#   type    = "A"
#   ttl     = "300"
#   records = [aws_eip.eip.public_ip]
# }

# output "name_server"{
#   value=aws_route53_zone.easy_aws.name_servers
# }
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

#------------------Create_RDS_MYSQL_For_Wordpress-----------
# Create a database server
# resource "aws_db_instance" "mysql_wordpress" {
#   engine         = "mysql"
#   engine_version = "5.7"
#   instance_class = "db.t1.micro"
#   name           = "wordpress_db"
#   username       = "root"
#   password       = "rootpasswd"
#   port           = "3306"
#   vpc_security_group_ids   = ["${aws_security_group.mydb1.id}"]

# }
# # Configure the MySQL provider based on the outcome of creating the aws_db_instance.
# provider "mysql" {
#   endpoint = "${aws_db_instance.mysql_wordpress.endpoint}"
#   username = "${aws_db_instance.mysql_wordpress.username}"
#   password = "${aws_db_instance.mysql_wordpress.password}"
# }

# resource "mysql_database" "app" {
#   name = "wordpress"
# }

# resource "mysql_user" "wp_user" {
#   user               = "worduser"
#   host               = "localhost"
#   plaintext_password = "wordpass"
# }

# resource "mysql_grant" "wp_user_priv" {
#   user       = "${mysql_user.wp_user.user}"
#   host       = "${mysql_user.wp_user.host}"
#   database   = "wordpress"
#   privileges = ["ALL"]
# }
# output "db_endpoint" {
#   value = aws_db_instance.mysql_wordpress.endpoint
# }
#-----------------------------------------------------------
# resource "aws_security_group" "wordpress_db_sg" {
#   name = "wordpress_db_sg"

#   vpc_id = aws_vpc.my_db_VPC.id

#   ingress {
#     from_port = 3306
#     to_port = 3306
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
# #-----------------------------------------------------------
# resource "aws_vpc" "my_db_VPC" {
#   cidr_block           = var.dbCIDRblock
# }
# #-----------------------------------------------------------
# resource "aws_subnet" "my_db_VPC_Subnet" {
#   vpc_id                  = aws_vpc.my_VPC.id
#   cidr_block              = var.db_subnetCIDRblock
# }
# #-----------------------------------------------------------
# #-----------------------------------------------------------
# resource "aws_internet_gateway" "my_db_VPC_GW" {
#  vpc_id = aws_vpc.my_db_VPC.id
# }
# #-----------------------------------------------------------
# resource "aws_route_table" "my_db_VPC_route_table" {
#  vpc_id = aws_vpc.my_db_VPC.id
# }
# #-----------------------------------------------------------
# resource "aws_route" "My_db_VPC_internet_access" {
#   route_table_id         = aws_route_table.my_db_VPC_route_table.id
#   destination_cidr_block = var.destinationCIDRblock
#   gateway_id             = aws_internet_gateway.my_db_VPC_GW.id
# }
# #-----------------------------------------------------------
# resource "aws_route_table_association" "My_db_VPC_association" {
#   subnet_id      = aws_subnet.my_VPC_Subnet.id
#   route_table_id = aws_route_table.my_db_VPC_route_table.id
# }
# #-----------------------------------------------------------