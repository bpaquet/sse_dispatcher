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

variable "sse_dispatcher_revision" {
  type = string
}