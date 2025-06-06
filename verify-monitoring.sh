#!/bin/bash
# Script to verify Prometheus and Grafana are accessible

# Get instance IPs from Terraform output
PROMETHEUS_IP=$(terraform -chdir=Terraform-monitoring output -raw prometheus_ip)
GRAFANA_IP=$(terraform -chdir=Terraform-monitoring output -raw grafana_ip)

echo "Checking Prometheus at http://$PROMETHEUS_IP:9090..."
curl -s -o /dev/null -w "%{http_code}" http://$PROMETHEUS_IP:9090/

echo "Checking Grafana at http://$GRAFANA_IP:3000..."
curl -s -o /dev/null -w "%{http_code}" http://$GRAFANA_IP:3000/

echo "Connecting to Prometheus instance to check service status..."
ssh -o StrictHostKeyChecking=no ec2-user@$PROMETHEUS_IP "sudo docker ps | grep prometheus"

echo "Connecting to Grafana instance to check service status..."
ssh -o StrictHostKeyChecking=no ec2-user@$GRAFANA_IP "sudo docker ps | grep grafana"