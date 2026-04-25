pipeline {
    agent {
        label 'agent2'
    }

    tools {
        nodejs 'NodeJS'
    }

    environment {
        AWS_ACCESS_KEY_ID     = "your-access-key-id"
        AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
        AWS_DEFAULT_REGION    = "us-east-1"
        SONAR_SCANNER_HOME = tool 'sonar-scanner'
        PATH = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
        DOCKER_IMAGE_NAME = "expresshub-app"
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
                sh 'docker run --rm -v $WORKSPACE:/app aquasec/trivy:latest fs --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed /app'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${env.DOCKER_IMAGE_NAME}:latest ."
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed ${env.DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                dir('terraform/dev') {
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def publicIp = sh(script: "cd terraform/dev && terraform output -raw public_ip", returnStdout: true).trim()
                    sh "scp -o StrictHostKeyChecking=no terraform/modules/ec2/user_data.sh ubuntu@${publicIp}:/home/ubuntu/"
                    sh "ssh -o StrictHostKeyChecking=no ubuntu@${publicIp} 'chmod +x /home/ubuntu/user_data.sh && /home/ubuntu/user_data.sh'"
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished. Cleaning up...'

            // Add a stage to destroy Terraform resources
            stage('Terraform Destroy') {
                dir('terraform/dev') {
                    sh 'terraform destroy -auto-approve'
                }
            }

            // This will clean up the workspace after the build
            cleanWs()

            // This will clean up unused Docker resources
            sh 'docker system prune -af'
        }
        success { echo 'Pipeline completed successfully!' }
        failure { echo 'Pipeline failed. Check the logs.' }
    }
}