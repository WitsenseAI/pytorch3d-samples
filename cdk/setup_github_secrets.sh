#!/bin/bash

# This script sets up GitHub secrets for your repository
# You need to have GitHub CLI (gh) installed and authenticated

# Set your GitHub repository
GITHUB_REPO="WitsenseAI/pytorch3d-samples"

# Set up AWS_ROLE_ARN secret
gh secret set AWS_ROLE_ARN --body="arn:aws:iam::329599624569:role/GitHubActionsRole" --repo $GITHUB_REPO

# Set up EC2_KEY_NAME secret
gh secret set EC2_KEY_NAME --body="github-actions-ec2-key" --repo $GITHUB_REPO

# Set up ECR_REPOSITORY_URI secret
gh secret set ECR_REPOSITORY_URI --body="329599624569.dkr.ecr.us-east-1.amazonaws.com/pytorch3d-app" --repo $GITHUB_REPO

# Check if private key file exists before setting EC2_SSH_KEY secret
if [ -f "github-actions-ec2-key.pem" ]; then
  gh secret set EC2_SSH_KEY --body="$(cat github-actions-ec2-key.pem)" --repo $GITHUB_REPO
  echo "EC2_SSH_KEY secret set from github-actions-ec2-key.pem"
else
  echo "Warning: github-actions-ec2-key.pem file not found. EC2_SSH_KEY secret not set."
  echo "You will need to set this secret manually with your private key."
fi

echo "GitHub secrets have been set up successfully!"
