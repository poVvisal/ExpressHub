#!/bin/bash
set -e

# Install Git and Docker
sudo apt-get update -y
sudo apt-get install -y git docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu
# Sets read, write, and execute permissions for all users on the Docker socket file
sudo chmod 777 /var/run/docker.sock
#Docker compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# Makes the Docker Compose binary executable.
sudo chmod +x /usr/local/bin/docker-compose
# Activates the changes made to the user group without requiring a system reboot.
sudo newgrp docker

# Clone the repository
# If the directory exists, pull the latest changes
if [ -d "/home/ubuntu/ExpressHub" ]; then
  cd /home/ubuntu/ExpressHub
  git pull
else
  git clone https://github.com/poVvisal/ExpressHub.git /home/ubuntu/ExpressHub
  cd /home/ubuntu/ExpressHub
fi

# Build the Docker image
sudo docker build -t foodexpress-js .

# Stop and remove any existing container
sudo docker stop foodexpress-js || true
sudo docker rm foodexpress-js || true

# Run the new container
sudo docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js

# Set the grafana password locally for the docker-compose execution
export GF_SECURITY_ADMIN_PASSWORD="${grafana_password}"

# deploying the monitoring stack
sudo -E docker-compose -f "./build-process/docker-compose.yml" up -d --build

