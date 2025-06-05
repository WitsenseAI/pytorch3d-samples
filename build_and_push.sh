#!/bin/bash

# Exit on error
set -e

# Get the ECR repository URI
ECR_REPO=$(aws ecr describe-repositories --repository-names gpu-batch-repo --query 'repositories[0].repositoryUri' --output text)

if [ -z "$ECR_REPO" ]; then
    echo "Error: Could not find ECR repository 'gpu-batch-repo'"
    echo "Make sure you've deployed the CDK stack and the repository exists"
    exit 1
fi

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REPO

# Build the Docker image
echo "Building Docker image..."
docker build -t gpu-batch-repo .

# Tag the image
echo "Tagging image as $ECR_REPO:latest"
docker tag gpu-batch-repo:latest $ECR_REPO:latest

# Push the image to ECR
echo "Pushing image to ECR..."
docker push $ECR_REPO:latest

echo "Done! Image pushed to $ECR_REPO:latest"