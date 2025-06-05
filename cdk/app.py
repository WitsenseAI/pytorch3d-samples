#!/usr/bin/env python3
import os
from aws_cdk import App, Environment
from gpu_batch_stack import GpuBatchStack

app = App()

GpuBatchStack(app, "GpuBatchStack",
    env=Environment(
        account=os.environ.get("CDK_DEFAULT_ACCOUNT"),
        region=os.environ.get("CDK_DEFAULT_REGION")
    )
)

app.synth()