variable "instance_type" {
  type = string
}

variable "keyname" {
  type = string
}

variable "scalefactor" {
  type = map(string)
}

variable "allow_ingress_ec2" {
  type = set(number)
}

variable "allow_ingress_elb" {
  type = set(number)
}

variable "health_check" {
  type = map(string)
  default = {
    "timeout"             = "5"
    "interval"            = "30"
    "path"                = "/"
    "port"                = 80
    "unhealthy_threshold" = "2"
  }
}