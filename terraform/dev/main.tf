module "ec2" {
  source = "../modules/ec2"

  instance_type = var.instance_type
  public_key    = var.public_key
  key_name      = var.key_name
  ami_id        = var.ami_id
  environment   = "dev"
}
