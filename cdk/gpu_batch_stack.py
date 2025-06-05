from aws_cdk import (
    Stack,
    RemovalPolicy,
    aws_ec2 as ec2,
    aws_batch as batch,
    aws_iam as iam,
    aws_ecr as ecr,
)
from constructs import Construct

class GpuBatchStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create VPC
        vpc = ec2.Vpc(self, "BatchVPC", max_azs=2)
        
        # Apply removal policy to VPC and its child resources
        vpc.apply_removal_policy(RemovalPolicy.DESTROY)
        
        # Create ECR repository for container images
        repository = ecr.Repository(self, "BatchRepository",
            repository_name="gpu-batch-repo",
            removal_policy=RemovalPolicy.DESTROY,
            empty_on_delete=True  # Required to delete a repo with images
        )

        # Create security group for batch compute resources
        security_group = ec2.SecurityGroup(
            self, "BatchSecurityGroup",
            vpc=vpc,
            description="Security group for AWS Batch compute resources",
            allow_all_outbound=True
        )
        security_group.apply_removal_policy(RemovalPolicy.DESTROY)

        # Create instance role and add required policies
        instance_role = iam.Role(
            self, "BatchInstanceRole",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com")
        )
        instance_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonECSTaskExecutionRolePolicy")
        )
        instance_role.apply_removal_policy(RemovalPolicy.DESTROY)

        # Create compute environment
        compute_environment = batch.ManagedEc2EcsComputeEnvironment(
            self, "GpuComputeEnvironment",
            vpc=vpc,
            instance_types=[
                ec2.InstanceType("g4dn.xlarge")  # GPU instance type
            ],
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
            compute_environment_name="GpuBatchEnv",
            instance_role=instance_role,
            security_groups=[security_group],
            minv_cpus=0,
            maxv_cpus=16
        )
        compute_environment.node.default_child.apply_removal_policy(RemovalPolicy.DESTROY)

        # Create job queue
        job_queue = batch.JobQueue(
            self, "GpuJobQueue",
            compute_environments=[
                batch.OrderedComputeEnvironment(
                    compute_environment=compute_environment,
                    order=1
                )
            ],
            job_queue_name="GpuJobQueue",
            priority=1
        )
        job_queue.node.default_child.apply_removal_policy(RemovalPolicy.DESTROY)

        # Create job definition with GPU support using L1 construct
        # since L2 construct doesn't directly support GPU requirements
        job_definition = batch.CfnJobDefinition(
            self, "GpuJobDefinition",
            type="container",
            container_properties={
                "image": repository.repository_uri + ":latest",
                "vcpus": 4,
                "memory": 16384,
                "command": ["echo", "GPU job started"],
                "resourceRequirements": [
                    {
                        "type": "GPU",
                        "value": "1"
                    }
                ]
            },
            platform_capabilities=["EC2"]
        )
        job_definition.apply_removal_policy(RemovalPolicy.DESTROY)