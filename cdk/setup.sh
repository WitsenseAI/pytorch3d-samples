#!/bin/bash

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt

# Install AWS CDK CLI locally
npm install

echo "Setup complete! To use the CDK CLI, run:"
echo "source .venv/bin/activate"
echo "npm run cdk -- <command>"
echo "For example: npm run cdk -- synth"