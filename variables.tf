variable "image" {
  default = "Centos 7"
}

variable "flavor" {
  default = "de.NBI.small"
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

variable "dnsupdatescript" {
  default = ""
}
variable "fqdn" {
  default = ""
}
