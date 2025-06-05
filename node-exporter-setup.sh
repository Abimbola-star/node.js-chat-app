#!/bin/bash

# Install Node Exporter on the Chat App server
# This script should be run on your chat application server

# Update and install required packages
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# Run Node Exporter container
sudo docker run -d \
  --name node-exporter \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host

echo "Node Exporter is now running on port 9100"
echo "Make sure your security group allows inbound traffic on port 9100"