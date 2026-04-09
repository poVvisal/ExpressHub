output "public_ip" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.foodexpress_server[*].public_ip
}

output "instance_id" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.foodexpress_server[*].id
}
