variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
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
  default     = "ami-0ec10929233384c7f"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "root_volume_size" {
  description = "The size of the root volume in gigabytes"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "The type of the root volume"
  type        = string
  default     = "gp2"
}
