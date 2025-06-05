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
  }

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    
    # Create directories for Prometheus
    mkdir -p /etc/prometheus
    mkdir -p /var/lib/prometheus
    
    # Create Prometheus config
    cat > /etc/prometheus/prometheus.yml <<'CONFIG'
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
    CONFIG
    
    # Run node exporter for local monitoring
    docker run -d \
      --name node-exporter \
      --net="host" \
      --pid="host" \
      -v "/:/host:ro,rslave" \
      quay.io/prometheus/node-exporter \
      --path.rootfs=/host
    
    # Run Prometheus with persistent config
    docker run -d \
      --name prometheus \
      -p 9090:9090 \
      -v /etc/prometheus:/etc/prometheus \
      -v /var/lib/prometheus:/prometheus \
      prom/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/prometheus \
      --web.console.libraries=/usr/share/prometheus/console_libraries \
      --web.console.templates=/usr/share/prometheus/consoles
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
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    
    # Create persistent storage for Grafana
    mkdir -p /var/lib/grafana
    
    # Create datasource provisioning directory
    mkdir -p /etc/grafana/provisioning/datasources
    
    # Create datasource config
    cat > /etc/grafana/provisioning/datasources/prometheus.yml <<'CONFIG'
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://${aws_instance.prometheus.private_ip}:9090
        isDefault: true
    CONFIG
    
    # Run Grafana with persistent storage and auto-provisioned datasource
    docker run -d \
      -p 3000:3000 \
      --name grafana \
      -v /var/lib/grafana:/var/lib/grafana \
      -v /etc/grafana/provisioning:/etc/grafana/provisioning \
      -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
      -e "GF_USERS_ALLOW_SIGN_UP=false" \
      -e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource" \
      grafana/grafana
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