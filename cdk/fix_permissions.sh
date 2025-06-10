#!/bin/bash

# Set your variables
ROLE_NAME="GitHubActionsRole"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
NEW_POLICY_NAME="GitHubActionsFullAccessPolicy"

# Create a comprehensive policy file
cat > full-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:*",
        "ecr:*",
        "iam:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create a new policy
echo "Creating new IAM policy with full permissions..."
POLICY_ARN=$(aws iam create-policy \
  --policy-name ${NEW_POLICY_NAME} \
  --policy-document file://full-permissions-policy.json \
  --query 'Policy.Arn' \
  --output text)

# Attach the new policy to the role
echo "Attaching new policy to role..."
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn ${POLICY_ARN}

echo "Policy created and attached successfully!"
echo "New policy ARN: ${POLICY_ARN}"

# Clean up
rm -f full-permissions-policy.json