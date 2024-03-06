variable "region" {
    default = "eastus"
}

variable "prefix" {
    default = "sco"
}

variable "vpc_address_space" {
    default = ["10.0.0.0/16"]
}

variable "subnet_address_space" {
    default = ["10.0.2.0/24"]
}

variable "admin_password" {
    default = "${env.VM_PASS}"
}
