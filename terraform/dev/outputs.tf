output "public_ip" {
  value = module.ec2.public_ip[0]
}

output "instance_id" {
  value = module.ec2.instance_id[0]
}
