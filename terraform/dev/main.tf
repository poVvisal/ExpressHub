module "ec2" {
  source = "../modules/ec2"

  instance_type    = var.instance_type
  public_key       = var.public_key
  key_name         = var.key_name
  ami_id           = var.ami_id
  environment      = "dev"
  instance_count   = var.instance_count
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type
  ssh_cidr_blocks  = ["117.20.115.254/32"]
  app_port_cidr_blocks = ["172.31.0.0/16"]
  existing_security_group_id = var.existing_security_group_id
  existing_key_name          = var.existing_key_name
  grafana_password = var.grafana_password
}
