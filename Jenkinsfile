pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    environment {
        // TODO: move these into Jenkins credentials ASAP
        AWS_ACCESS_KEY_ID                 = "accesskey123"
        AWS_SECRET_ACCESS_KEY             = "secretkey123"
        AWS_DEFAULT_REGION                = "us-east-1"
        TF_VAR_existing_security_group_id = "sg-12345678"
        TF_VAR_existing_key_name          = "final"
        TF_VAR_grafana_password           = "khmer4ever"
        TF_VAR_instance_count             = "2"

        TF_DIR                            = "terraform/dev"
        TF_PLUGIN_CACHE_DIR               = "/var/lib/jenkins/.terraform.d/plugin-cache"
        TRIVY_CACHE_DIR                   = "/var/lib/jenkins/trivy-cache"

        SONAR_SCANNER_HOME                = tool('sonar-scanner')
        PATH                              = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"

        DOCKER_IMAGE_NAME                 = "expresshub-app"
        CONTAINER_NAME                    = "foodexpress-js"
        APP_PORT                          = "5000"
        HEALTHCHECK_PATH                  = "/"
        TRIVY_VERSION                     = "0.69.3"
        GIT_BRANCH                        = "main"
    }

    stages {
        stage('Prepare & Clone') {
            steps {
                sh '''
                    set -e
                    mkdir -p "$TF_PLUGIN_CACHE_DIR" "$TRIVY_CACHE_DIR"
                '''
                git branch: "${GIT_BRANCH}", url: 'https://github.com/poVvisal/ExpressHub.git'
            }
        }

        stage('Static Analysis & Security') {
            parallel {
                stage('SonarQube') {
                    steps {
                        withSonarQubeEnv('jenkins2sonar') {
                            sh '''
                                set -e
                                sonar-scanner \
                                  -Dsonar.projectKey=ExpressHub \
                                  -Dsonar.projectName=ExpressHub \
                                  -Dsonar.sources=.
                            '''
                        }
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

                stage('Trivy FS Scan') {
                    steps {
                        sh '''
                            set -e
                            docker run --rm \
                              -v "$TRIVY_CACHE_DIR:/root/.cache/" \
                              -v "$WORKSPACE:/app" \
                              "aquasec/trivy:${TRIVY_VERSION}" fs /app \
                              --scanners vuln,secret,misconfig \
                              --exit-code 1 \
                              --severity HIGH,CRITICAL \
                              --ignore-unfixed \
                              --skip-dirs /app/terraform \
                              --format template \
                              --template "@contrib/html.tpl" \
                              -o /app/trivy-fs-report.html
                        '''
                        archiveArtifacts artifacts: 'trivy-fs-report.html', fingerprint: true
                    }
                }
            }
        }

        stage('Build & Image Scan') {
            steps {
                sh '''
                    set -e
                    IMAGE_TAG="${GIT_COMMIT:-$(git rev-parse --short HEAD)}"
                    echo "$IMAGE_TAG" > image_tag.txt

                    docker build -t ${DOCKER_IMAGE_NAME}:$IMAGE_TAG -t ${DOCKER_IMAGE_NAME}:latest .

                    docker run --rm \
                      -v "$TRIVY_CACHE_DIR:/root/.cache/" \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v "$WORKSPACE:/app" \
                      "aquasec/trivy:${TRIVY_VERSION}" image ${DOCKER_IMAGE_NAME}:$IMAGE_TAG \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --format template \
                      --template "@contrib/html.tpl" \
                      -o /app/trivy-image-report.html
                '''
                archiveArtifacts artifacts: 'trivy-image-report.html', fingerprint: true
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-credentials',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh '''
                        set -e
                        IMAGE_TAG=$(cat image_tag.txt)
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                        docker tag ${DOCKER_IMAGE_NAME}:$IMAGE_TAG $DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:$IMAGE_TAG
                        docker tag ${DOCKER_IMAGE_NAME}:latest $DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:latest
                        docker push $DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:$IMAGE_TAG
                        docker push $DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:latest
                        echo "$DOCKER_USERNAME/${DOCKER_IMAGE_NAME}:$IMAGE_TAG" > image_ref.txt
                    '''
                }
            }
        }

        stage('Terraform Provisioning') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        export TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"
                        terraform init -input=false
                        terraform apply -input=false -var="instance_count=${TF_VAR_instance_count}" -auto-approve
                        terraform output -json > "$WORKSPACE/terraform-outputs.json"
                    '''
                }
                archiveArtifacts artifacts: 'terraform-outputs.json', fingerprint: true
            }
        }

        stage('Read EC2 Outputs') {
            steps {
                sh '''
                    set -e
                    python3 -c '
import json, sys
data = json.load(open("terraform-outputs.json"))
ips = data.get("public_ip", {}).get("value", [])
ips = [ips] if isinstance(ips, str) else ips
with open("ec2_public_ips.txt", "w") as f:
    f.write("\\n".join([str(ip).strip() for ip in ips if str(ip).strip()]))
'
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''#!/bin/bash
                        set -euo pipefail
                        chmod 600 "$SSH_KEY_FILE"
                        IMAGE_REF=$(cat "$WORKSPACE/image_ref.txt")
                        FAILED=0

                        cat > deploy-ec2.sh <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IMAGE_REF="$1"
APP_PORT="$2"
DOCKER_USERNAME="$3"
DOCKER_PASSWORD="$4"

cd /home/ubuntu/ExpressHub
git config --global --add safe.directory /home/ubuntu/ExpressHub
git pull

cd build-process
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

export IMAGE_REF=$IMAGE_REF
export APP_PORT=$APP_PORT

docker-compose pull foodexpress-js
docker-compose up -d foodexpress-js

echo "Waiting for app to spin up..."
for i in $(seq 1 12); do
    if curl -s -f http://localhost:$APP_PORT/api/status > /dev/null; then
        echo "Deployment successful! App is healthy."
        exit 0
    fi
    sleep 5
done

echo "CRITICAL: Health check failed! Dumping logs:"
docker-compose logs foodexpress-js
exit 1
REMOTE_SCRIPT

                        while IFS= read -r EC2_HOST || [ -n "$EC2_HOST" ]; do
                            [ -z "$EC2_HOST" ] && continue
                            echo "Deploying to $EC2_HOST"
                            
                            for i in $(seq 1 15); do
                                if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY_FILE" "$SSH_USER@$EC2_HOST" 'echo ok' >/dev/null 2>&1; then break; fi
                                sleep 10
                            done

                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" deploy-ec2.sh "$SSH_USER@$EC2_HOST:/tmp/deploy-ec2.sh"
                            
                            if ! ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$SSH_USER@$EC2_HOST" "chmod +x /tmp/deploy-ec2.sh && /tmp/deploy-ec2.sh '$IMAGE_REF' '$APP_PORT' '$DOCKER_USERNAME' '$DOCKER_PASSWORD'"; then
                                echo "Deployment failed on $EC2_HOST"
                                FAILED=1
                            fi
                        done < "$WORKSPACE/ec2_public_ips.txt"

                        if [ "$FAILED" -ne 0 ]; then exit 1; fi
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                set +e
                docker run --rm -v "$TRIVY_CACHE_DIR:/cache" alpine:latest find /cache -type f -mtime +7 -delete || true
                docker run --rm -v "$TF_PLUGIN_CACHE_DIR:/cache" alpine:latest find /cache -type f -mtime +30 -delete || true
            '''
            cleanWs(deleteDirs: true, disableDeferredWipeout: true)
        }
    }
}