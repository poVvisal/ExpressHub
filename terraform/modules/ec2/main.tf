resource "aws_key_pair" "foodexpress_key" {
  count      = var.existing_key_name == "" ? 1 : 0
  key_name   = var.key_name
  public_key = var.public_key
}

resource "aws_security_group" "foodexpress_sg" {
  count       = var.existing_security_group_id == "" ? 1 : 0
  name        = "foodexpress-sg-${var.environment}"
  description = "Allow SSH, HTTP, and app traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidr_blocks
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.app_port_cidr_blocks
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.app_port_cidr_blocks
    description = "Grafana"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.app_port_cidr_blocks
    description = "Prometheus"
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.app_port_cidr_blocks
    description = "Node Exporter"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "foodexpress_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  count         = var.instance_count
  associate_public_ip_address = var.associate_public_ip_address

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }

  key_name               = var.existing_key_name != "" ? var.existing_key_name : aws_key_pair.foodexpress_key[0].key_name
  vpc_security_group_ids = [var.existing_security_group_id != "" ? var.existing_security_group_id : aws_security_group.foodexpress_sg[0].id]
  user_data = templatefile("${path.module}/user_data.sh", {
    grafana_password = var.grafana_password
  })

  tags = {
    Name        = "FoodExpress-App-Server-${var.environment}"
    Environment = var.environment
  }
}
