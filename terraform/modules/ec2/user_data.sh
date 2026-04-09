#!/bin/bash
set -e

sudo apt update -y
sudo apt upgrade -y

sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker ubuntu
