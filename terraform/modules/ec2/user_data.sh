#!/bin/bash
set -e

# Install Git and Docker
sudo apt-get update -y
sudo apt-get install -y git docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

# Clone the repository
git clone https://github.com/poVvisal/ExpressHub.git /home/ubuntu/ExpressHub
cd /home/ubuntu/ExpressHub

# Build and run the Docker container
sudo docker build -t foodexpress-js .
sudo docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js
