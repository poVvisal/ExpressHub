output "public_ip" {
  value = aws_instance.foodexpress_server.public_ip
}

output "instance_id" {
  value = aws_instance.foodexpress_server.id
}
