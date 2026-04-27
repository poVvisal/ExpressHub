pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    environment {
        AWS_ACCESS_KEY_ID                 = "REDACTED-ACCESS-KEY"
        AWS_SECRET_ACCESS_KEY             = "REDACTED-SECRET"
        AWS_DEFAULT_REGION                = "us-east-1"
        TF_VAR_existing_security_group_id = "sg-123456789abcdef0"
        TF_VAR_existing_key_name          = "final"
        TF_VAR_grafana_password           = "REDACTED-PASSWORD"

        TF_DIR                            = "terraform/dev"
        TF_STATE_DIR                      = "/var/lib/jenkins/terraform-state/expresshub/dev"
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

        stage('Prepare Persistent Directories') {
            steps {
                sh '''
                    set -e
                    mkdir -p "$TF_STATE_DIR" \
                             "$TF_PLUGIN_CACHE_DIR" \
                             "$TRIVY_CACHE_DIR"
                '''
            }
        }

        stage('Clone Repository') {
            steps {
                git branch: "${GIT_BRANCH}", url: 'https://github.com/poVvisal/ExpressHub.git'
            }
        }

        stage('SonarQube Analysis') {
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

                    docker run --rm \
                      -v "$TRIVY_CACHE_DIR:/root/.cache/" \
                      -v "$WORKSPACE:/app" \
                      "aquasec/trivy:${TRIVY_VERSION}" fs /app \
                      --scanners vuln,secret,misconfig \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --skip-dirs /app/terraform \
                      --format json \
                      -o /app/trivy-fs-report.json
                '''
                archiveArtifacts artifacts: 'trivy-fs-report.html,trivy-fs-report.json', fingerprint: true
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    set -e
                    IMAGE_TAG="${GIT_COMMIT:-$(git rev-parse --short HEAD)}"
                    echo "$IMAGE_TAG" > image_tag.txt

                    docker build \
                      -t ${DOCKER_IMAGE_NAME}:$IMAGE_TAG \
                      -t ${DOCKER_IMAGE_NAME}:latest \
                      .
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    set -e
                    IMAGE_TAG=$(cat image_tag.txt)

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

                    docker run --rm \
                      -v "$TRIVY_CACHE_DIR:/root/.cache/" \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v "$WORKSPACE:/app" \
                      "aquasec/trivy:${TRIVY_VERSION}" image ${DOCKER_IMAGE_NAME}:$IMAGE_TAG \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --format json \
                      -o /app/trivy-image-report.json
                '''
                archiveArtifacts artifacts: 'trivy-image-report.html,trivy-image-report.json', fingerprint: true
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

        stage('Restore Terraform State') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        if [ -f "$TF_STATE_DIR/terraform.tfstate" ]; then
                          cp -f "$TF_STATE_DIR/terraform.tfstate" terraform.tfstate
                          echo "Restored terraform.tfstate from Jenkins storage."
                        else
                          echo "No existing terraform.tfstate backup found. Proceeding with fresh state."
                        fi

                        if [ -f "$TF_STATE_DIR/terraform.tfstate.backup" ]; then
                          cp -f "$TF_STATE_DIR/terraform.tfstate.backup" terraform.tfstate.backup
                          echo "Restored terraform.tfstate.backup from Jenkins storage."
                        fi
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        export TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"
                        terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        terraform validate
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        terraform plan -input=false -out=tfplan
                        terraform show -no-color tfplan > tfplan.txt
                    '''
                }
                archiveArtifacts artifacts: "${TF_DIR}/tfplan.txt", fingerprint: true
            }
        }

        stage('Terraform Apply') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        terraform apply -input=false -auto-approve tfplan
                        terraform output -json > "$WORKSPACE/terraform-outputs.json"
                    '''
                }
                archiveArtifacts artifacts: 'terraform-outputs.json', fingerprint: true
            }
        }

        stage('Persist Terraform State') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set +e
                        if [ -s terraform.tfstate ] && grep -q '"version"' terraform.tfstate; then
                            if [ -f "$TF_STATE_DIR/terraform.tfstate" ] && ! cmp -s terraform.tfstate "$TF_STATE_DIR/terraform.tfstate"; then
                                cp -f "$TF_STATE_DIR/terraform.tfstate" "$TF_STATE_DIR/terraform.tfstate.$(date +%Y%m%d%H%M%S).archive"
                            fi
                            cp -f terraform.tfstate "$TF_STATE_DIR/terraform.tfstate"
                            echo "Terraform state successfully persisted."
                        else
                            echo "Warning: Local terraform.tfstate is empty or invalid. Skipping persistence to prevent corruption."
                        fi

                        if [ -s terraform.tfstate.backup ]; then
                            cp -f terraform.tfstate.backup "$TF_STATE_DIR/terraform.tfstate.backup"
                        fi
                    '''
                }
            }
        }

        stage('Read EC2 Output') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        set -e
                        # Use correct output names: public_ip and instance_id
                        terraform output -raw public_ip > "$WORKSPACE/ec2_public_ip.txt"
                        if terraform output instance_id >/dev/null 2>&1; then
                            terraform output -raw instance_id > "$WORKSPACE/ec2_instance_id.txt"
                        fi
                        cat "$WORKSPACE/ec2_public_ip.txt"
                    '''
                }
            }
        }

        stage('Wait for EC2 SSH') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -e
                        EC2_HOST=$(cat "$WORKSPACE/ec2_public_ip.txt")
                        chmod 600 "$SSH_KEY_FILE"

                        for i in $(seq 1 18); do
                          if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY_FILE" "$SSH_USER@$EC2_HOST" 'echo EC2 is reachable' >/dev/null 2>&1; then
                            echo "EC2 SSH is ready."
                            exit 0
                          fi
                          echo "Waiting for EC2 SSH to become ready... attempt $i/18"
                          sleep 10
                        done

                        echo "EC2 SSH did not become ready in time."
                        exit 1
                    '''
                }
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
                    sh '''
                        set -e

                        EC2_HOST=$(cat "$WORKSPACE/ec2_public_ip.txt")
                        IMAGE_REF=$(cat "$WORKSPACE/image_ref.txt")

                        chmod 600 "$SSH_KEY_FILE"

                        cat > deploy-ec2.sh <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="$1"
CONTAINER_NAME="$2"
APP_PORT="$3"
HEALTHCHECK_PATH="$4"
DOCKER_USERNAME="$5"
DOCKER_PASSWORD="$6"

OLD_CONTAINER="${CONTAINER_NAME}-previous"
HEALTH_URL="http://localhost:${APP_PORT}${HEALTHCHECK_PATH}"

http_health_check() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$HEALTH_URL" <<'PY'
import sys
import urllib.request
url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=5) as r:
        code = getattr(r, "status", r.getcode())
        sys.exit(0 if 200 <= code < 300 else 1)
except Exception:
    sys.exit(1)
PY
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -q --spider --timeout=5 "$HEALTH_URL"
    return $?
  fi

  return 127
}

tcp_health_check() {
  if command -v bash >/dev/null 2>&1; then
    timeout 3 bash -c "</dev/tcp/localhost/${APP_PORT}" >/dev/null 2>&1
    return $?
  fi
  return 127
}

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
docker pull "$IMAGE_REF"

if docker ps -a --format '{{.Names}}' | grep -qx "$OLD_CONTAINER"; then
  docker rm -f "$OLD_CONTAINER" || true
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker stop "$CONTAINER_NAME" || true
  docker rename "$CONTAINER_NAME" "$OLD_CONTAINER"
fi

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  "$IMAGE_REF"

for i in $(seq 1 18); do
  if http_health_check; then
    echo "Application HTTP health check passed: $HEALTH_URL"
    docker rm -f "$OLD_CONTAINER" >/dev/null 2>&1 || true
    exit 0
  fi
  http_status=$?

  if [ "$http_status" -eq 127 ] && tcp_health_check; then
    echo "HTTP check tools unavailable; TCP port ${APP_PORT} is reachable"
    docker rm -f "$OLD_CONTAINER" >/dev/null 2>&1 || true
    exit 0
  fi

  echo "Waiting for application health... attempt $i/18"
  sleep 10
done

echo "New container failed health check, initiating rollback."
docker logs "$CONTAINER_NAME" || true
docker rm -f "$CONTAINER_NAME" || true

if docker ps -a --format '{{.Names}}' | grep -qx "$OLD_CONTAINER"; then
  echo "Old container found. Rolling back to ${OLD_CONTAINER}..."
  docker rename "$OLD_CONTAINER" "$CONTAINER_NAME"
  docker start "$CONTAINER_NAME" || true

  for j in $(seq 1 6); do
    if http_health_check; then
      echo "Rollback successful. Previous container is serving HTTP successfully."
      exit 1
    fi
    http_status=$?

    if [ "$http_status" -eq 127 ] && tcp_health_check; then
      echo "Rollback recovered TCP reachability on port ${APP_PORT}."
      exit 1
    fi

    echo "Waiting for rolled-back application health... attempt $j/6"
    sleep 5
  done

  echo "CRITICAL: Rollback failed. Application is unresponsive."
  docker logs "$CONTAINER_NAME" || true
  exit 1
else
  echo "CRITICAL: No previous container found to execute rollback."
  exit 1
fi
REMOTE_SCRIPT

                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" deploy-ec2.sh "$SSH_USER@$EC2_HOST:/tmp/deploy-ec2.sh"

                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$SSH_USER@$EC2_HOST" \
                          "chmod +x /tmp/deploy-ec2.sh && /tmp/deploy-ec2.sh \
                          '$IMAGE_REF' \
                          '$CONTAINER_NAME' \
                          '$APP_PORT' \
                          '${HEALTHCHECK_PATH}' \
                          '$DOCKER_USERNAME' \
                          '$DOCKER_PASSWORD'"

                        rm -f deploy-ec2.sh
                    '''
                }
            }
        }
    }

    post {
        always {
            dir("${env.TF_DIR}") {
                sh '''
                    set +e
                    if [ -s terraform.tfstate ] && grep -q '"version"' terraform.tfstate; then
                        if [ -f "$TF_STATE_DIR/terraform.tfstate" ] && ! cmp -s terraform.tfstate "$TF_STATE_DIR/terraform.tfstate"; then
                            cp -f "$TF_STATE_DIR/terraform.tfstate" "$TF_STATE_DIR/terraform.tfstate.$(date +%Y%m%d%H%M%S).archive"
                        fi
                        cp -f terraform.tfstate "$TF_STATE_DIR/terraform.tfstate"
                    fi

                    if [ -s terraform.tfstate.backup ]; then
                        cp -f terraform.tfstate.backup "$TF_STATE_DIR/terraform.tfstate.backup"
                    fi
                    rm -f tfplan tfplan.txt .tf_plan_exit_code
                '''
            }
            sh '''
                set +e
                # Use Docker containers to run find as root, circumventing permission denied errors on cache files
                docker run --rm -v "$TRIVY_CACHE_DIR:/cache" alpine:latest find /cache -type f -mtime +7 -delete || true
                docker run --rm -v "$TF_PLUGIN_CACHE_DIR:/cache" alpine:latest find /cache -type f -mtime +30 -delete || true
                docker run --rm -v "$TF_STATE_DIR:/state" alpine:latest find /state -name "*.archive" -type f -mtime +30 -delete || true
            '''
            cleanWs(deleteDirs: true, disableDeferredWipeout: true)
        }

        success {
            echo 'Pipeline completed successfully. Infrastructure was applied and the immutable app image was deployed to EC2.'
        }

        failure {
            echo 'Pipeline failed. Infrastructure state and container status have been logged.'
        }
    }
}