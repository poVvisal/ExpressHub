#!/bin/bash
set -e

KEY_NAME="devops-key"
SG_DESCRIPTION="Jenkins-Sonarqube-SG"
TF_BUCKET="expresshub-tfstate-v1"
TF_TABLE="expresshub-state-lock"

echo "=== Starting cleanup ==="

# 1. Terminate instances named 'Jenkins' and 'Sonarqube'
echo "Looking for instances with tags Name=Jenkins or Name=Sonarqube..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Jenkins,Sonarqube" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS > /dev/null

    # Wait for each instance to be terminated
    for ID in $INSTANCE_IDS; do
        echo -n "Waiting for $ID to terminate"
        while true; do
            STATE=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "terminated")
            if [ "$STATE" = "terminated" ]; then
                echo " Done."
                break
            else
                echo -n "."
                sleep 5
            fi
        done
    done
else
    echo "No matching instances found."
fi

# 2. Delete the security group (by description)
echo "Looking for security group with description '$SG_DESCRIPTION'..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=description,Values=$SG_DESCRIPTION" --query 'SecurityGroups[0].GroupId' --output text)
if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    echo "Deleting security group $SG_ID"
    # Give network interfaces time to detach
    sleep 10
    aws ec2 delete-security-group --group-id "$SG_ID" || {
        echo "Retrying in 20 seconds..."
        sleep 20
        aws ec2 delete-security-group --group-id "$SG_ID"
    }
else
    echo "No security group with description '$SG_DESCRIPTION' found."
fi

# 3. Delete the key pair from AWS
echo "Deleting key pair '$KEY_NAME' from AWS..."
aws ec2 delete-key-pair --key-name "$KEY_NAME" 2>/dev/null && echo "Deleted." || echo "Key pair not found or already deleted."

# 4. Remove the local private key file
LOCAL_KEY="${HOME}/${KEY_NAME}.pem"
if [ -f "$LOCAL_KEY" ]; then
    echo "Removing local file $LOCAL_KEY"
    rm -f "$LOCAL_KEY"
else
    echo "Local key file not found."
fi

# 5. Delete Terraform DynamoDB Table
echo "Deleting DynamoDB table '$TF_TABLE'..."
aws dynamodb delete-table --table-name "$TF_TABLE" --region us-east-1 2>/dev/null && echo "Deleted." || echo "Table not found or already deleted."

# 6. Delete Terraform S3 Bucket (Requires clearing versions first)
echo "Emptying and deleting S3 bucket '$TF_BUCKET'..."
if aws s3api head-bucket --bucket "$TF_BUCKET" 2>/dev/null; then
    # Delete all object versions
    VERSIONS=$(aws s3api list-object-versions --bucket "$TF_BUCKET" --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')
    if [ "$VERSIONS" != "null" ] && [ -n "$VERSIONS" ]; then
        aws s3api delete-objects --bucket "$TF_BUCKET" --delete "$VERSIONS" > /dev/null 2>&1
    fi
    
    # Delete all delete markers
    MARKERS=$(aws s3api list-object-versions --bucket "$TF_BUCKET" --output=json --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')
    if [ "$MARKERS" != "null" ] && [ -n "$MARKERS" ]; then
        aws s3api delete-objects --bucket "$TF_BUCKET" --delete "$MARKERS" > /dev/null 2>&1
    fi
    
    # Finally, remove the empty bucket
    aws s3 rb s3://"$TF_BUCKET" --force 2>/dev/null && echo "Deleted." || echo "Failed to delete bucket."
else
    echo "Bucket '$TF_BUCKET' not found or access denied."
fi

echo "=== Cleanup complete ==="