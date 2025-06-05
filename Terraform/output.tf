output "public_ip" {
  value = aws_eip.nodejs_app_eip.public_ip
  description = "Public IP address of chat application server"
}

output "ansible_master_public_ip" {
  value = aws_eip.ansible_master_eip.public_ip
  description = "Public IP address of the ansible master"
}

/*output "grafana_public_ip" {
  value = aws_eip.grafana_eip.public_ip
  description = "Public IP address of the grafana server"
}

output "prometheus_public_ip" {
  value = aws_eip.prometheus_eip.public_ip
  description = "Public IP address of the Prometheus server"
}*/