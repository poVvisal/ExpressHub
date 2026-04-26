pipeline {
    agent {
        label 'agent2'
    }

    tools {
        nodejs 'NodeJS'
    }

    environment {
        // ⚠️ REDACTED: Store these in Jenkins credentials instead of plain text!
        AWS_ACCESS_KEY_ID     = "REDACTED-ACCESS-KEY"
        AWS_SECRET_ACCESS_KEY = "REDACTED-SECRET-KEY"
        AWS_DEFAULT_REGION    = "us-east-1"
        TF_VAR_grafana_password = "REDACTED-PASSWORD"
        TF_VAR_existing_security_group_id = "sg-0795c0d85a643e9b5"
        TF_VAR_existing_key_name          = "new-key"

        TF_DIR                = "terraform/dev"
        SONAR_SCANNER_HOME    = tool 'sonar-scanner'
        PATH                  = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
        DOCKER_IMAGE_NAME     = "expresshub-app"
    }

    stages {

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/poVvisal/ExpressHub.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('jenkins2sonar') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=ExpressHub \
                          -Dsonar.projectName=ExpressHub \
                          -Dsonar.sources=.
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
                        }
                    }
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    docker run --rm \
                      -v $WORKSPACE:/app \
                      aquasec/trivy:latest fs \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      /app
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build --cache-from ${env.DOCKER_IMAGE_NAME}:latest -t ${env.DOCKER_IMAGE_NAME}:latest ."
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v \$WORKSPACE:/app \
                      aquasec/trivy:latest image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --format template --template "@contrib/html.tpl" -o /app/trivy-report.html \
                      ${env.DOCKER_IMAGE_NAME}:latest
                """
                archiveArtifacts artifacts: 'trivy-report.html'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    sh """
                        echo "\$DOCKER_PASSWORD" | docker login -u "\$DOCKER_USERNAME" --password-stdin
                        docker tag ${env.DOCKER_IMAGE_NAME}:latest \$DOCKER_USERNAME/${env.DOCKER_IMAGE_NAME}:latest
                        docker push \$DOCKER_USERNAME/${env.DOCKER_IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                dir("${env.TF_DIR}") {
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def EC2_IP = ""
                    dir("${env.TF_DIR}") {
                        EC2_IP = sh(script: "terraform output -raw public_ip", returnStdout: true).trim()
                    }
                    
                    withCredentials([
                        usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME'), 
                        sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')
                    ]) {
                        echo "Waiting for EC2 instance to initialize SSH and finish user_data installation..."
                        sleep(time: 90, unit: 'SECONDS')
                        
                        // Force Docker username to lowercase and allow Groovy to resolve it locally
                        def dockerUser = DOCKER_USERNAME.toLowerCase()
                        def sshCommand = "ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ubuntu@${EC2_IP}"
                        
                        // Use double quotes for ssh commands so Groovy injects the image name and username perfectly
                        sh """
                            ${sshCommand} "sudo docker pull ${dockerUser}/${env.DOCKER_IMAGE_NAME}:latest"
                            ${sshCommand} "sudo docker stop foodexpress-js || true"
                            ${sshCommand} "sudo docker rm foodexpress-js || true"
                            ${sshCommand} "sudo docker run -d --name foodexpress-js -p 3000:3000 ${dockerUser}/${env.DOCKER_IMAGE_NAME}:latest"
                        """
                    }
                }
            }
        }
    }

    post {
        failure {
            echo '❌ Pipeline failed!'
            script {
                def stateFile = "${env.WORKSPACE}/${env.TF_DIR}/terraform.tfstate"
                if (fileExists(stateFile)) {
                    echo '🔥 Destroying Terraform infrastructure due to failure..ah nerb.'
                    dir("${env.TF_DIR}") {
                        sh 'terraform destroy -auto-approve'
                    }
                    echo '✅ Terraform infrastructure destroyed.'
                } else {
                    echo '⚠️ No Terraform state found — skipping destroy.'
                }
            }
            cleanWs()
            sh 'docker system prune -af'
        }

        success {
            echo '✅ Pipeline completed successfully! Infrastructure is live.'
            cleanWs()
            sh 'docker system prune -af'
        }
    }
}