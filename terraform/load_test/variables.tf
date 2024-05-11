variable "region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "c6i.large"
}

variable "desired_capacity" {
  type    = number
  default = 10
}

variable "min_size" {
  type    = number
  default = 0
}

variable "max_size" {
  type    = number
  default = 10
}

variable "nb_users" {
  type    = number
  default = 5000
}

variable "version_override" {
  type = string
}