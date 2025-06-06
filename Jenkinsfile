pipeline {
    agent any
    
    environment {
        CHAT_APP_IP = credentials('chat-app-ip')
        SSH_KEY     = credentials('ssh-key')
    }
    
    stages {
        stage('Checkout') {
            steps {
               git branch: 'dev', url: 'https://github.com/Abimbola-star/node.js-chat-app.git'
            }
        }
        
        stage('Package') {
            steps {
                sh 'tar -czf chat-app.tar.gz app.js package.json index.html'
                archiveArtifacts artifacts: 'chat-app.tar.gz', fingerprint: true
            }
        }
        
        stage('Deploy App') {
             steps {
                sshagent(['ssh-key']) {
                    sh 'ansible-playbook ansible-playbook.yml -i hosts.ini'
                }
            }
        }
        
        stage('Deploy Monitoring') {
            steps {
                sh '''
                    # Create persistent directories for Prometheus
                    sudo mkdir -p /opt/prometheus/config
                    
                    # Create Prometheus config
                    cat > prometheus-config.yml << EOF
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
      - targets: ['${CHAT_APP_IP}:9100']
EOF
                    
                    # Copy config to persistent location
                    sudo cp prometheus-config.yml /opt/prometheus/config/prometheus.yml
                    
                    # Stop and remove existing containers if they exist
                    docker stop prometheus || true
                    docker rm prometheus || true
                    
                    # Run Prometheus container
                    docker run -d --name prometheus \
                      -p 9090:9090 \
                      -v /opt/prometheus/config:/etc/prometheus \
                      --restart always \
                      prom/prometheus
                '''
                
                sh '''
                    # Create persistent directories for Grafana
                    sudo mkdir -p /opt/grafana/provisioning/datasources
                    sudo mkdir -p /opt/grafana/data
                    
                    # Create datasource config
                    cat > grafana-datasource.yml << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
                    
                    # Copy config to persistent location
                    sudo cp grafana-datasource.yml /opt/grafana/provisioning/datasources/prometheus.yml
                    
                    # Stop and remove existing containers if they exist
                    docker stop grafana || true
                    docker rm grafana || true
                    
                    # Run Grafana container
                    docker run -d --name grafana \
                      -p 3000:3000 \
                      --link prometheus:prometheus \
                      -v /opt/grafana/provisioning:/etc/grafana/provisioning \
                      -v /opt/grafana/data:/var/lib/grafana \
                      -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
                      -e "GF_USERS_ALLOW_SIGN_UP=false" \
                      --restart always \
                      grafana/grafana
                '''
                
                sh '''
                    # Create startup script
                    cat > docker-monitoring-startup.sh << EOF
#!/bin/bash
# Start Prometheus
docker start prometheus || docker run -d --name prometheus \\
  -p 9090:9090 \\
  -v /opt/prometheus/config:/etc/prometheus \\
  --restart always \\
  prom/prometheus

# Start Grafana
docker start grafana || docker run -d --name grafana \\
  -p 3000:3000 \\
  --link prometheus:prometheus \\
  -v /opt/grafana/provisioning:/etc/grafana/provisioning \\
  -v /opt/grafana/data:/var/lib/grafana \\
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \\
  -e "GF_USERS_ALLOW_SIGN_UP=false" \\
  --restart always \\
  grafana/grafana
EOF
                    
                    # Install startup script
                    sudo cp docker-monitoring-startup.sh /usr/local/bin/
                    sudo chmod +x /usr/local/bin/docker-monitoring-startup.sh
                    
                    # Create systemd service
                    cat > docker-monitoring.service << EOF
[Unit]
Description=Docker Monitoring Services
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/docker-monitoring-startup.sh

[Install]
WantedBy=multi-user.target
EOF
                    
                    # Install and enable service
                    sudo cp docker-monitoring.service /etc/systemd/system/
                    sudo systemctl daemon-reload
                    sudo systemctl enable docker-monitoring.service
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "Checking Chat App..."
                    curl -s http://${CHAT_APP_IP}:3000/ || echo "Chat App not responding"
                    
                    echo "Checking Prometheus..."
                    curl -s http://localhost:9090/-/healthy || echo "Prometheus not healthy"
                    
                    echo "Checking Grafana..."
                    curl -s http://localhost:3000/api/health || echo "Grafana not healthy"
                    
                    echo "Deployment URLs:"
                    echo "Chat App: http://${CHAT_APP_IP}:3000"
                    echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
                    echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/admin)"
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
        always {
            cleanWs(deleteDirs: true, patterns: [
                [pattern: '*.tar.gz', type: 'INCLUDE']
            ])
        }
    }
}