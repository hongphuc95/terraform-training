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
  type = set(string)
}

variable "allow_ingress_elb" {
  type = set(string)
}