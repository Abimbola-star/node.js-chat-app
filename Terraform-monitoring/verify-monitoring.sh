#!/bin/bash
# Script to verify Prometheus and Grafana are accessible

# Get instance IPs from Terraform output
PROMETHEUS_IP=$(terraform output -raw prometheus_ip)
GRAFANA_IP=$(terraform output -raw grafana_ip)

echo "Prometheus IP: $PROMETHEUS_IP"
echo "Grafana IP: $GRAFANA_IP"
echo ""

# Check if instances are reachable via ping
echo "Checking if instances are reachable..."
ping -n 1 $PROMETHEUS_IP > nul 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Prometheus instance is reachable"
else
  echo "❌ Prometheus instance is not reachable"
fi

ping -n 1 $GRAFANA_IP > nul 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Grafana instance is reachable"
else
  echo "❌ Grafana instance is not reachable"
fi
echo ""

# Check HTTP endpoints with verbose output
echo "Checking Prometheus at http://$PROMETHEUS_IP:9090..."
curl -v http://$PROMETHEUS_IP:9090/ 2>&1 | grep "< HTTP"

echo ""
echo "Checking Grafana at http://$GRAFANA_IP:3000..."
curl -v http://$GRAFANA_IP:3000/ 2>&1 | grep "< HTTP"

echo ""
echo "Troubleshooting tips:"
echo "1. EC2 instances may need more time to initialize (5-10 minutes)"
echo "2. Check AWS Console to verify instances are running"
echo "3. Try accessing the URLs in a web browser:"
echo "   - Prometheus: http://$PROMETHEUS_IP:9090"
echo "   - Grafana: http://$GRAFANA_IP:3000"
echo "4. If still not working, try reapplying Terraform:"
echo "   terraform destroy -auto-approve"
echo "   terraform apply -auto-approve"