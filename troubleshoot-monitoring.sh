#!/bin/bash

# This script helps troubleshoot Prometheus and Grafana connectivity issues
# Run this on your monitoring instances

echo "=== Checking Docker Service ==="
sudo systemctl status docker

echo "=== Checking Docker Containers ==="
sudo docker ps -a

echo "=== Checking if Prometheus is Running ==="
sudo docker logs prometheus

echo "=== Checking if Grafana is Running ==="
sudo docker logs grafana

echo "=== Checking Network Connectivity ==="
sudo netstat -tulpn | grep -E '9090|3000'

echo "=== Checking Security Group Rules ==="
# This requires AWS CLI to be configured
aws ec2 describe-security-groups --group-ids YOUR_SECURITY_GROUP_ID

echo "=== Checking User Data Script Execution ==="
sudo cat /var/log/cloud-init-output.log

echo "=== Checking if Services are Accessible Locally ==="
curl -v http://localhost:9090
curl -v http://localhost:3000