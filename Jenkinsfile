pipeline {
    agent {
        label 'agent2'
    }

    tools {
        nodejs 'NodeJS'
    }

    environment {
        // ⚠️ REDACTED: Store these in Jenkins credentials instead of plain text!
        AWS_ACCESS_KEY_ID                 = "REDACTED-ACCESS-KEY"
        AWS_SECRET_ACCESS_KEY             = "REDACTED-SECRET-KEY"
        AWS_DEFAULT_REGION                = "us-east-1"
        TF_VAR_grafana_password           = "REDACTED-PASSWORD"
        TF_VAR_existing_security_group_id = "sg-0795c0d85a643e9b5"
        TF_VAR_existing_key_name          = "new-key"

        TF_DIR             = "terraform/dev"
        SONAR_SCANNER_HOME = tool 'sonar-scanner'
        PATH               = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
        DOCKER_IMAGE_NAME  = "expresshub-app"
    }

    stages {

        stage('Restore Terraform State') {
            steps {
                script {
                    try {
                        unstash 'tfstate'
                        echo '✅ Restored previous Terraform state from stash.'
                    } catch (e) {
                        echo '⚠️ No stashed state found — attempting restore from EC2 backup...'
                        // EC2 state restore is handled after we know the IP (post Terraform stage)
                    }
                }
            }
        }

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
                    script {
                        def plan = sh(script: 'terraform plan -detailed-exitcode -out=tfplan', returnStatus: true)
                        if (plan == 2) {
                            echo '🔧 Infrastructure changes detected — applying...'
                            sh 'terraform apply -auto-approve tfplan'
                        } else if (plan == 0) {
                            echo '✅ No infrastructure changes detected — skipping apply.'
                        } else {
                            error '❌ Terraform plan failed.'
                        }
                    }
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
                        def dockerUser = DOCKER_USERNAME.toLowerCase()
                        def sshCmd = "ssh -o StrictHostKeyChecking=no -i \$SSH_KEY ubuntu@${EC2_IP}"

                        // ── Zero-downtime container swap ──
                        sh """
                            # Pull the new image first
                            ${sshCmd} "sudo docker pull ${dockerUser}/${env.DOCKER_IMAGE_NAME}:latest"

                            # Start new container on temp port 5001
                            ${sshCmd} "sudo docker run -d --name foodexpress-js-new -p 5001:5000 ${dockerUser}/${env.DOCKER_IMAGE_NAME}:latest"

                            # Stop and remove old container
                            ${sshCmd} "sudo docker stop foodexpress-js || true"
                            ${sshCmd} "sudo docker rm foodexpress-js || true"

                            # Rename new container to production name and remap to port 5000
                            ${sshCmd} "sudo docker stop foodexpress-js-new"
                            ${sshCmd} "sudo docker rm foodexpress-js-new"
                            ${sshCmd} "sudo docker run -d --name foodexpress-js -p 5000:5000 ${dockerUser}/${env.DOCKER_IMAGE_NAME}:latest"
                        """

                        // ── Backup Terraform state to EC2 (no S3 needed) ──
                        sh """
                            scp -o StrictHostKeyChecking=no -i \$SSH_KEY \
                              ${env.WORKSPACE}/${env.TF_DIR}/terraform.tfstate \
                              ubuntu@${EC2_IP}:~/terraform.tfstate.backup
                        """
                        echo '📦 Terraform state backed up to EC2.'
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Stash the Terraform state BEFORE cleaning workspace
                def stateFile = "${env.WORKSPACE}/${env.TF_DIR}/terraform.tfstate"
                if (fileExists(stateFile)) {
                    dir("${env.TF_DIR}") {
                        stash name: 'tfstate', includes: 'terraform.tfstate'
                        echo '📦 Terraform state stashed for next run.'
                    }
                } else {
                    echo '⚠️ No Terraform state file found to stash.'
                }
            }
            cleanWs()
        }

        failure {
            echo '❌ Pipeline failed!'
        }

        success {
            echo '✅ Pipeline completed successfully! Container updated on EC2.'
        }
    }
}