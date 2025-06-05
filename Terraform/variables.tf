variable "aws_region" {
  description = "AWS region"
  type        = string
  default = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type = string
  default = "ami-0e9bbd70d26d7cf4f"
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type = string
  default = "t2.micro"
}

variable "key_name" {
  description = "Key name for the EC2 instance"
  type = string
  default = "amazonlinux.pem"
}