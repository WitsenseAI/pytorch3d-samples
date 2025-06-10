#!/bin/bash

# Set your variables
ROLE_NAME="GitHubActionsRole"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create the updated permissions policy file
cat > updated-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:*",
        "ecr:*",
        "iam:PassRole",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:TagRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Update the policy
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsPolicy"

echo "Updating IAM policy with additional permissions..."
aws iam create-policy-version \
  --policy-arn ${POLICY_ARN} \
  --policy-document file://updated-permissions-policy.json \
  --set-as-default

echo "Policy updated successfully!"
echo "The GitHub Actions role now has the necessary permissions to manage IAM resources including instance profiles."

# Clean up
rm -f updated-permissions-policy.json