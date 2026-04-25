pipeline {
    agent {
        label 'agent2'
    }

    tools {
        nodejs 'NodeJS'
    }

    environment {
        AWS_ACCESS_KEY_ID     = ""your-access-key-id""
        AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
        AWS_DEFAULT_REGION    = "us-east-1"
        SONAR_SCANNER_HOME    = tool 'sonar-scanner'
        PATH                  = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
        DOCKER_IMAGE_NAME     = "expresshub-app"
        TF_DIR                = "terraform/dev"
        TF_VAR_grafana_password = credentials('grafana-admin-password')
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
                sh "docker build -t ${env.DOCKER_IMAGE_NAME}:latest ."
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:latest image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      ${env.DOCKER_IMAGE_NAME}:latest
                """
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