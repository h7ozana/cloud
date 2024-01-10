variable "key_name_1" {
  type        = string
  description = "Bastion EC2 KeyPair to enable SSH access to the instances"
  default     = "BasKEY"
}

variable "key_name_2" {
  type        = string
  description = "RDS EC2 KeyPair to enable SSH access to the instances"
  default     = "Putty_KEY"
}

variable "latest_ami_id" {
  type        = string
  description = "(DO NOT CHANGE)"
  default     = "ami-0bfd23bc25c60d5a1"
}

