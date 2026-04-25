resource "aws_key_pair" "foodexpress_key" {
  key_name   = var.key_name
  public_key = var.public_key
}

resource "aws_security_group" "foodexpress_sg" {
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

  key_name               = aws_key_pair.foodexpress_key.key_name
  vpc_security_group_ids = [aws_security_group.foodexpress_sg.id]
  user_data              = file("${path.module}/user_data.sh")

  tags = {
    Name        = "FoodExpress-App-Server-${var.environment}"
    Environment = var.environment
  }
}
