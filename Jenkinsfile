pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Package') {
            steps {
                sh 'tar -czf chat-app.tar.gz app.js package.json index.html'
            }
        }
        
        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        ansible-playbook -i hosts.ini ansible-playbook.yml --private-key=$SSH_KEY
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}