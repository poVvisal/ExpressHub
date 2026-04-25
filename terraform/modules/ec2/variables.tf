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

variable "ssh_cidr_blocks" {
  description = "The CIDR blocks allowed to access the instances via SSH."
  type        = list(string)
  default     = ["117.20.115.254/32"]
}

variable "http_cidr_blocks" {
  description = "The CIDR blocks allowed to access the instances via HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port_cidr_blocks" {
  description = "The CIDR blocks allowed to access the application port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = true
}
