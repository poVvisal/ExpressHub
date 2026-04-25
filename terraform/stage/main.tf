module "ec2" {
  source = "../modules/ec2"

  instance_type    = var.instance_type
  public_key       = var.public_key
  key_name         = var.key_name
  ami_id           = var.ami_id
  environment      = "stage"
  instance_count   = var.instance_count
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type
  existing_security_group_id = var.existing_security_group_id
  existing_key_name          = var.existing_key_name
  grafana_password           = var.grafana_password
}
