# SAM Deployment Instructions

## Prerequisites
- AWS CLI configured with credentials
- Docker Desktop running (required for Python 3.12 builds)
- SAM CLI installed

## First-Time Deployment

### Step 1: Navigate to infrastructure directory
```bash
cd ~/aws-coding-copilot/backend/infrastructure
```

### Step 2: Build with Docker
```bash
sam build --use-container
```

This uses Docker to build with Python 3.12 (Lambda's runtime), avoiding local Python version issues.

### Step 3: Deploy
```bash
sam deploy
```

The `samconfig.toml` has all settings pre-configured. No prompts will appear.

### Step 4: Get API endpoint
```bash
aws cloudformation describe-stacks --stack-name prod-coding-copilot --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' --output text
```

## Troubleshooting

### "Early Validation" Error
If you get validation errors about existing resources:

1. Check for orphaned S3 buckets:
```bash
aws s3 ls | grep coding-copilot
```

2. Delete orphaned buckets:
```bash
aws s3 rb s3://BUCKET-NAME --force
```

3. Retry deployment

### "Binary validation failed for python"
This means your local Python version doesn't match Lambda's runtime (3.12).

**Solution**: Always use `sam build --use-container`

### Stack Status Check
```bash
aws cloudformation describe-stacks --stack-name prod-coding-copilot --query 'Stacks[0].StackStatus'
```

### Delete Failed Stack
If the stack is in a bad state:
```bash
aws cloudformation delete-stack --stack-name prod-coding-copilot
```

Wait for deletion to complete, then redeploy.

## Update Deployment

After code changes:

```bash
cd ~/aws-coding-copilot/backend/infrastructure
sam build --use-container
sam deploy
```

No additional flags needed - `samconfig.toml` handles everything.
