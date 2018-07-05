variable "image" {
  default = "CentOS 7 - latest"
}

variable "flavor" {
  default = "ssc.medium"
}

variable "ssh_key_file" {
  default = "~/.ssh/id_rsa"
}

variable "ssh_user_name" {
  default = "centos"
}

variable "external_gateway" {}

variable "pool" {
  default = "public"
}

variable "certificate" {}

variable "email" {}
