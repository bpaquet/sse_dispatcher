variable "region" {
  type = string
}

variable "prefix" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "c6i.large"
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "docker_image" {
  type = string
}

variable "dd_secret" {
  type = string
}

variable "dd_tags" {
  type    = string
  default = ""
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 0
}

variable "max_size" {
  type    = number
  default = 10
}

variable "health_check_min_cluster_size" {
  type    = number
  default = 1
}

variable "ssl_secret" {
  type = string
}

variable "acm_domain" {
  type    = string
  default = ""
}