module "ec2" {
  source = "../modules/ec2"

  instance_type    = var.instance_type
  public_key       = var.public_key
  key_name         = var.key_name
  ami_id           = var.ami_id
  environment      = "prod"
  instance_count   = var.instance_count
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type
}
