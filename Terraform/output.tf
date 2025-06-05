output "public_ip" {
  value = aws_eip.nodejs_app_eip.public_ip
  description = "Public IP address of chat application server"
}

output "ansible_master_public_ip" {
  value = aws_eip.ansible_master_eip.public_ip
  description = "Public IP address of the ansible master"
}

