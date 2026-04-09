#!/bin/bash
set -e

# Install Git and Docker
sudo apt-get update -y
sudo apt-get install -y git docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

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
