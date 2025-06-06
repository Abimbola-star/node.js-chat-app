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
    }
        
        stage('Deploy Monitoring') {
            steps {
                sh '''
                    # Create directories for Prometheus
                    mkdir -p prometheus/config
                    
                    # Create Prometheus config
                    cat > prometheus/config/prometheus.yml << EOF
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
                    
                    # Stop and remove existing containers if they exist
                    docker stop prometheus || true
                    docker rm prometheus || true
                    
                    # Run Prometheus container
                    docker run -d --name prometheus \
                      -p 9090:9090 \
                      -v ${WORKSPACE}/prometheus/config:/etc/prometheus \
                      --restart unless-stopped \
                      prom/prometheus
                '''
                
                sh '''
                    # Create directories for Grafana
                    mkdir -p grafana/provisioning/datasources
                    
                    # Create datasource config
                    cat > grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
                    
                    # Stop and remove existing containers if they exist
                    docker stop grafana || true
                    docker rm grafana || true
                    
                    # Run Grafana container
                    docker run -d --name grafana \
                      -p 3000:3000 \
                      --link prometheus:prometheus \
                      -v ${WORKSPACE}/grafana/provisioning:/etc/grafana/provisioning \
                      -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
                      -e "GF_USERS_ALLOW_SIGN_UP=false" \
                      --restart unless-stopped \
                      grafana/grafana
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
            cleanWs(deleteDirs: false, patterns: [
                [pattern: 'prometheus/**', type: 'EXCLUDE'], 
                [pattern: 'grafana/**', type: 'EXCLUDE'],
                [pattern: '*.tar.gz', type: 'INCLUDE']
            ])
        }
    }