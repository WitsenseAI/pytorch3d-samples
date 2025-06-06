#!/bin/bash

# Run it only once. 

# Set your variables
GITHUB_ORG="WitsenseAI"
GITHUB_REPO="pytorch3d-samples"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ROLE_NAME="GitHubActionsRole"
KEY_NAME="github-actions-ec2-key"
AWS_REGION="us-east-1"
ECR_REPO_NAME="pytorch3d-app"

echo "Setting up AWS resources for GitHub Actions..."

# Create the trust policy file for all repositories in the organization
cat > org-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/*:*"
        }
      }
    }
  ]
}
EOF

# Create the permissions policy file
cat > permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:*",
        "ecr:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Check if OIDC provider exists
echo "Checking if GitHub OIDC provider exists..."
if aws iam list-open-id-connect-providers | grep -q "token.actions.githubusercontent.com"; then
  echo "GitHub OIDC provider already exists."
else
  echo "Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
fi

# Check if role exists
echo "Checking if IAM role exists..."
if aws iam get-role --role-name ${ROLE_NAME} 2>/dev/null; then
  echo "Role ${ROLE_NAME} already exists. Updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-document file://org-trust-policy.json
else
  echo "Creating IAM role ${ROLE_NAME}..."
  aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://org-trust-policy.json
fi

# Check if policy exists
echo "Checking if IAM policy exists..."
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsPolicy"
if aws iam get-policy --policy-arn ${POLICY_ARN} 2>/dev/null; then
  echo "Policy GitHubActionsPolicy already exists."
else
  echo "Creating IAM policy GitHubActionsPolicy..."
  aws iam create-policy \
    --policy-name GitHubActionsPolicy \
    --policy-document file://permissions-policy.json
fi

# Check if policy is attached to role
echo "Checking if policy is attached to role..."
if aws iam list-attached-role-policies --role-name ${ROLE_NAME} | grep -q ${POLICY_ARN}; then
  echo "Policy is already attached to role."
else
  echo "Attaching policy to role..."
  aws iam attach-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-arn ${POLICY_ARN}
fi

# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query "Role.Arn" --output text)
echo "AWS_ROLE_ARN: ${ROLE_ARN}"

# Check if key pair exists
echo "Checking if EC2 key pair exists..."
if aws ec2 describe-key-pairs --key-names ${KEY_NAME} 2>/dev/null; then
  echo "Key pair ${KEY_NAME} already exists."
  echo "Note: We cannot retrieve the private key for an existing key pair."
  echo "If you don't have the private key, consider deleting the key pair with:"
  echo "aws ec2 delete-key-pair --key-name ${KEY_NAME}"
  echo "and then run this script again."
else
  echo "Creating EC2 key pair ${KEY_NAME}..."
  aws ec2 create-key-pair \
    --key-name ${KEY_NAME} \
    --query "KeyMaterial" \
    --output text > ${KEY_NAME}.pem
  
  # Set proper permissions for the key file
  chmod 400 ${KEY_NAME}.pem
  echo "Private key saved to ${KEY_NAME}.pem"
fi

# Output the key name
echo "EC2_KEY_NAME: ${KEY_NAME}"

# Check if ECR repository exists
echo "Checking if ECR repository exists..."
if aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} 2>/dev/null; then
  echo "ECR repository ${ECR_REPO_NAME} already exists."
else
  echo "Creating ECR repository ${ECR_REPO_NAME}..."
  aws ecr create-repository --repository-name ${ECR_REPO_NAME}
fi

# Get ECR repository URI
ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
echo "ECR_REPOSITORY_URI: ${ECR_REPO_URI}"

# Create a file with GitHub CLI commands to set up secrets
cat > setup_github_secrets.sh << EOF
#!/bin/bash

# This script sets up GitHub secrets for your repository
# You need to have GitHub CLI (gh) installed and authenticated

# Set your GitHub repository
GITHUB_REPO="${GITHUB_ORG}/${GITHUB_REPO}"

# Set up AWS_ROLE_ARN secret
gh secret set AWS_ROLE_ARN --body="${ROLE_ARN}" --repo \$GITHUB_REPO

# Set up EC2_KEY_NAME secret
gh secret set EC2_KEY_NAME --body="${KEY_NAME}" --repo \$GITHUB_REPO

# Set up ECR_REPOSITORY_URI secret
gh secret set ECR_REPOSITORY_URI --body="${ECR_REPO_URI}" --repo \$GITHUB_REPO

# Check if private key file exists before setting EC2_SSH_KEY secret
if [ -f "${KEY_NAME}.pem" ]; then
  gh secret set EC2_SSH_KEY --body="\$(cat ${KEY_NAME}.pem)" --repo \$GITHUB_REPO
  echo "EC2_SSH_KEY secret set from ${KEY_NAME}.pem"
else
  echo "Warning: ${KEY_NAME}.pem file not found. EC2_SSH_KEY secret not set."
  echo "You will need to set this secret manually with your private key."
fi

echo "GitHub secrets have been set up successfully!"
EOF

chmod +x setup_github_secrets.sh

echo ""
echo "===== GITHUB SECRETS SETUP ====="
echo "To set up GitHub secrets automatically, install GitHub CLI (gh) and run:"
echo "./setup_github_secrets.sh"
echo ""
echo "Or manually set the following secrets in your GitHub repository:"
echo "1. AWS_ROLE_ARN: ${ROLE_ARN}"
echo "2. EC2_KEY_NAME: ${KEY_NAME}"
echo "3. ECR_REPOSITORY_URI: ${ECR_REPO_URI}"
if [ -f "${KEY_NAME}.pem" ]; then
  echo "4. EC2_SSH_KEY: Contents of ${KEY_NAME}.pem file"
  echo "   To view the EC2 SSH key content, run: cat ${KEY_NAME}.pem"
else
  echo "4. EC2_SSH_KEY: You need to provide your existing private key for ${KEY_NAME}"
fi

# Clean up JSON files
rm -f org-trust-policy.json permissions-policy.json

echo ""
echo "Setup complete!"