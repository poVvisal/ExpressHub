variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "public_key" {
  description = "Public key content for EC2 key pair"
  type        = string
}

variable "key_name" {
  description = "Key name in AWS"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
