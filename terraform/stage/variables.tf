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
