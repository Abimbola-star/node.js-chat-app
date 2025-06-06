provider "aws" {
  region = var.aws_region
}

# Security group for monitoring instances
resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Security group for Prometheus and Grafana"

  # Grafana UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana web interface"
  }

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus web interface"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node Exporter metrics"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "monitoring-security-group"
  }
}

# Prometheus instance
resource "aws_instance" "prometheus" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    # Update system and install Docker
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    
    # Create directories for Prometheus
    mkdir -p /etc/prometheus
    mkdir -p /var/lib/prometheus
    
    # Create Prometheus config
    cat > /etc/prometheus/prometheus.yml <<'EOC'
    global:
      scrape_interval: 15s
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
          
      - job_name: 'chat_app'
        static_configs:
          - targets: ['${var.chat_app_ip}:9100']
    EOC
    
    # Fix variable interpolation in config
    sed -i "s/\${var.chat_app_ip}/${var.chat_app_ip}/g" /etc/prometheus/prometheus.yml
    
    # Run node exporter for local monitoring
    docker run -d \
      --name node-exporter \
      --restart always \
      --net="host" \
      --pid="host" \
      -v "/:/host:ro,rslave" \
      quay.io/prometheus/node-exporter \
      --path.rootfs=/host
    
    # Run Prometheus with persistent config
    docker run -d \
      --name prometheus \
      --restart always \
      -p 9090:9090 \
      -v /etc/prometheus:/etc/prometheus \
      -v /var/lib/prometheus:/prometheus \
      prom/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/prometheus \
      --web.console.libraries=/usr/share/prometheus/console_libraries \
      --web.console.templates=/usr/share/prometheus/consoles
      
    # Wait for Prometheus to start and verify it's running
    sleep 30
    curl -s http://localhost:9090/-/healthy || echo "Prometheus not healthy"
    
    # Disable SELinux if it's causing issues
    setenforce 0 || true
    
    # Make sure ports are open in security groups
    iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
    iptables -A INPUT -p tcp --dport 9100 -j ACCEPT
  EOF

  tags = {
    Name = "prometheus-server"
  }
}

# Grafana instance
resource "aws_instance" "grafana" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    # Update system and install Docker
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    
    # Create persistent storage for Grafana
    mkdir -p /var/lib/grafana
    
    # Create datasource provisioning directory
    mkdir -p /etc/grafana/provisioning/datasources
    
    # Create datasource config
    cat > /etc/grafana/provisioning/datasources/prometheus.yml <<EOC
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://${aws_instance.prometheus.private_ip}:9090
        isDefault: true
    EOC
    
    # Run Grafana with persistent storage and auto-provisioned datasource
    docker run -d \
      -p 3000:3000 \
      --name grafana \
      --restart always \
      -v /var/lib/grafana:/var/lib/grafana \
      -v /etc/grafana/provisioning:/etc/grafana/provisioning \
      -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
      -e "GF_USERS_ALLOW_SIGN_UP=false" \
      -e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource" \
      grafana/grafana
      
    # Wait longer for Grafana to start
    sleep 30
    curl -s http://localhost:3000/api/health || echo "Grafana not healthy"
    
    # Disable SELinux if it's causing issues
    setenforce 0 || true
    
    # Make sure ports are open
    iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
    
    # Output completion message to logs
    echo "Grafana setup complete. Access at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
  EOF

  tags = {
    Name = "grafana-server"
  }
}

# Output the public IPs
output "prometheus_ip" {
  value = aws_instance.prometheus.public_ip
}

output "grafana_ip" {
  value = aws_instance.grafana.public_ip
}