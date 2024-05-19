variable "cluster-name" {
    default = "terraform-eks-demo"
    type    = string
}

variable "vpc_id" {
    default = "terraform-vpc"
    type    = string
}

variable "node-name" {
    default = "nodegroup1"
    type    = string
}