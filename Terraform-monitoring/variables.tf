variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI in us-east-1
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "chat_app_ip" {
  description = "IP address of the chat application server"
  type        = string
}