variable "project_name" {
  default = "greenroad"
}

variable "instance_type" {
  default = "t3.small"
}

variable "ssh_key_name" {
  default = "greenroad-key"
}

# Your existing ECR repository - Terraform will NOT manage this
variable "ecr_repository" {
  default = "809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app"
}
