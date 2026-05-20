terraform {
  backend "http" {
    address        = "https://tfstate.devExpressHub"
    update_method  = "PUT"
    lock_address   = "https://tfstate.devExpressHub/lock"
    unlock_address = "https://tfstate.devExpressHub/unlock"
    lock_method    = "LOCK"
    unlock_method  = "LOCK"
    username       = ""
    password       = ""
  }
}

provider "aws" {
  region = var.aws_region
}
