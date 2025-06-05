# AWS Batch with GPU Support

This CDK project creates an AWS Batch environment with GPU-enabled EC2 instances.

## Components

- VPC with public and private subnets
- IAM roles for Batch service and EC2 instances
- ECR repository for container images (with auto-delete enabled)
- Batch compute environment using g4dn.xlarge GPU instances
- Batch job queue
- Batch job definition configured for GPU workloads

## Deployment Instructions

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Bootstrap your AWS environment (if not already done):
   ```
   cdk bootstrap
   ```

3. Deploy the stack:
   ```
   cdk deploy
   ```

4. Build and push your Docker image to the created ECR repository:
   ```bash
   # Get the ECR repository URI
   export ECR_REPO=$(aws ecr describe-repositories --repository-names gpu-batch-repo --query 'repositories[0].repositoryUri' --output text)
   
   # Login to ECR
   aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REPO
   
   # Build and push the image
   docker build -t $ECR_REPO:latest .
   docker push $ECR_REPO:latest
   ```

## Submitting Jobs

After deployment, you can submit GPU jobs to the created job queue using the AWS CLI or SDK:

```bash
aws batch submit-job \
    --job-name gpu-test-job \
    --job-queue GpuJobQueue \
    --job-definition GpuJobDefinition
```

## Cleanup

To delete all resources including the ECR repository:

```bash
cdk destroy
```

All resources including the ECR repository will be deleted thanks to the removal policies set in the stack.