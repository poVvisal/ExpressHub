#!/bin/bash
set -e

# 1. Update OS and Install Dependencies
sudo apt-get update -y
sudo apt-get install -y git docker.io curl

# 2. Configure Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu
sudo chmod 777 /var/run/docker.sock
sudo chmod -R 777 /home/ubuntu
sudo chmod 666 /var/run/docker.sock

# Set ownership to the ubuntu user
sudo chown ubuntu:ubuntu /home/ubuntu /home/ubuntu/.ssh /home/ubuntu/.ssh/authorized_keys

# Set strict permissions
sudo chmod 755 /home/ubuntu
sudo chmod 700 /home/ubuntu/.ssh
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys


# 3. Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo newgrp docker

# 4. Clone the repository for the Monitoring Stack setup
if [ -d "/home/ubuntu/ExpressHub" ]; then
  cd /home/ubuntu/ExpressHub
  git pull
else
  git clone https://github.com/poVvisal/ExpressHub.git /home/ubuntu/ExpressHub
  cd /home/ubuntu/ExpressHub
fi

# Fix ownership since cloud-init runs as root
chown -R ubuntu:ubuntu /home/ubuntu/ExpressHub

# 5. Write env file so GF_SECURITY_ADMIN_PASSWORD persists for all future docker-compose runs
echo "GF_SECURITY_ADMIN_PASSWORD=${grafana_password}" > /home/ubuntu/ExpressHub/build-process/.env

# 6. Deploy the Monitoring Stack (Infrastructure)
export GF_SECURITY_ADMIN_PASSWORD="${grafana_password}"
sudo -E docker-compose -f "/home/ubuntu/ExpressHub/build-process/docker-compose.yml" up -d prometheus grafana node-exporter