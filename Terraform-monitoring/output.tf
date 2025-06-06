output "grafana_public_ip" {
  value = aws_instance.grafana.public_ip
  description = "Public IP address of the grafana server"
}

output "prometheus_public_ip" {
  value = aws_instance.prometheus.public_ip
  description = "Public IP address of the Prometheus server"
}