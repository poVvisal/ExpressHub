#!/bin/bash
set -e  # exit on error

# ---------------------------
# Configuration
# ---------------------------
AMI_ID="ami-0ec10929233384c7f"
INSTANCE_TYPE="t3.medium"
KEY_NAME="devops-key"
SG_NAME="devops-sg-$(date +%s)"
SG_DESCRIPTION="Jenkins-Sonarqube-SG"
VOLUME_SIZE=32

# Ports to open (additional SSH port 22 is added for convenience)
PORTS=(3000 9000 9100 8080 80 9090 5000 22)

# User-data script (same as provided in the question)
read -r -d '' USER_DATA <<'EOF' || true
#!/bin/bash

# 1. Logging: Monitor progress in /var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting System Setup..."

# 2. Update and Install Dependencies (Non-interactive)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y fontconfig openjdk-21-jre libatomic1 ca-certificates curl gnupg

# 3. Setup Docker GPG Key and Repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Components
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
#Docker compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 5. Set Permissions
# Ensuring the ubuntu user can run docker without sudo
usermod -aG docker ubuntu

# Activates the changes made to the user group without requiring a system reboot
newgrp docker

chmod -R 777 /home/ubuntu

# Sets read, write, and execute permissions for all users on the Docker socket file
sudo chmod 777 /var/run/docker.sock

echo "Setup Complete. Java version:"
java -version
EOF

# ---------------------------
# 1. Create ED25519 key pair and print private key
# ---------------------------
echo "Creating ED25519 key pair: $KEY_NAME"
KEY_MATERIAL=$(aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type ed25519 --query 'KeyMaterial' --output text)

echo "=================================================="
echo "PRIVATE KEY CONTENT (save it securely):"
echo "=================================================="
echo "$KEY_MATERIAL"
echo "=================================================="

# Also save to a file for later use (optional)
echo "$KEY_MATERIAL" > "${HOME}/${KEY_NAME}.pem"
chmod 400 "${HOME}/${KEY_NAME}.pem"

# ---------------------------
# 2. Create security group
# ---------------------------
echo "Creating security group: $SG_NAME"
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "$SG_DESCRIPTION" \
    --query 'GroupId' --output text)

for port in "${PORTS[@]}"; do
    echo "Opening inbound TCP port $port"
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port "$port" \
        --cidr 0.0.0.0/0 > /dev/null
done

# ---------------------------
# 3. Find default VPC and a public subnet
# ---------------------------
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
if [ -z "$DEFAULT_VPC_ID" ] || [ "$DEFAULT_VPC_ID" == "None" ]; then
    echo "ERROR: No default VPC found." >&2
    exit 1
fi
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
    --query 'Subnets[0].SubnetId' --output text)
if [ -z "$SUBNET_ID" ]; then
    # Fallback to any subnet in the default VPC
    SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" --query 'Subnets[0].SubnetId' --output text)
fi

# ---------------------------
# 4. Launch the two instances
# ---------------------------
declare -A INSTANCE_IPS
for NAME in Jenkins Sonarqube; do
    echo "Launching $NAME instance..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --subnet-id "$SUBNET_ID" \
        --associate-public-ip-address \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3}" \
        --user-data "$(echo "$USER_DATA" | base64 -w 0)" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" \
        --query 'Instances[0].InstanceId' --output text)

    # Wait for the instance to get a public IP
    echo -n "Waiting for $NAME to get a public IP"
    PUBLIC_IP=""
    while [ -z "$PUBLIC_IP" ]; do
        PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)
        echo -n "."
        sleep 3
    done
    echo " Done."
    INSTANCE_IPS[$NAME]=$PUBLIC_IP
done

# ---------------------------
# 5. Create Terraform State Resources
# ---------------------------
echo "Creating S3 bucket for Terraform state (expresshub-tfstate-v1)..."
aws s3api create-bucket \
  --bucket expresshub-tfstate-v1 \
  --region us-east-1

echo "Enabling versioning on the S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket expresshub-tfstate-v1 \
  --versioning-configuration Status=Enabled

echo "Waiting for S3 bucket to propagate..."
sleep 10

echo "Creating DynamoDB table for state locking (expresshub-state-lock)..."
aws dynamodb create-table \
  --table-name expresshub-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 > /dev/null

# ---------------------------
# 6. Final output
# ---------------------------
echo ""
echo "================== SUMMARY =================="
echo "Private key (ED25519): (see above)"
echo "Key pair name: $KEY_NAME"
echo "Security Group ID: $SG_ID"
echo "Jenkins public IP: ${INSTANCE_IPS[Jenkins]}"
echo "Sonarqube public IP: ${INSTANCE_IPS[Sonarqube]}"
echo "Terraform State S3 Bucket: expresshub-tfstate-v1"
echo "Terraform Lock DynamoDB: expresshub-state-lock"
echo "=============================================="
echo "SSH command example: ssh -i ~/${KEY_NAME}.pem ubuntu@${INSTANCE_IPS[Jenkins]}"