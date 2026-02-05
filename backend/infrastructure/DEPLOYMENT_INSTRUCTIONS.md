# SAM Deployment Instructions

## Prerequisites
- AWS CLI configured with credentials
- Docker Desktop running (required for Python 3.12 builds)
- SAM CLI installed

## ⚠️ IMPORTANT: Region Configuration

This project is configured for **us-east-2**. Your AWS CLI should match this region to avoid deployment failures.

### Check Your Region
```bash
aws configure get region
```

If this doesn't return `us-east-2`, either:

**Option 1**: Update your AWS CLI default region
```bash
aws configure set region us-east-2
```

**Option 2**: Use the automated deployment script (recommended)
```bash
./deploy-safe.sh
```

The automated script will detect region mismatches and fix them automatically.

## First-Time Deployment

### Step 1: Navigate to infrastructure directory
```bash
cd backend/infrastructure
```

(From your repository root directory)

### Step 2: Build Lambda Container Image
```bash
sam build
```

This builds a Docker container image for the Lambda function using the `Dockerfile` in `backend/lambda/`.

**Note**: SAM will automatically use Docker to build the container image. No `--use-container` flag needed since we're deploying as a container image (PackageType: Image).

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

### "Cannot Replace Named Resource" Error

If you see this error:
```
CloudFormation cannot update a stack when a custom-named resource requires replacing.
```

**Solution**: The template now uses auto-generated function names to avoid this issue. This allows CloudFormation to replace resources when needed without conflicts.

**What Changed**: The template previously used a custom `FunctionName: ${Environment}-coding-copilot-chat`. This has been removed to allow CloudFormation to auto-generate function names (e.g., `prod-coding-copilot-CodingCopilotFunction-ABC123`).

**Impact**:
- ✅ CloudFormation can now replace the Lambda function during updates
- ✅ Future deployments won't hit "cannot replace" errors
- ✅ All permissions and integrations remain intact
- ✅ The API Gateway endpoint URL remains the same

**If you previously had a custom function name**:
1. The old `prod-coding-copilot-chat` function will be deleted automatically during the next deployment
2. A new function with an auto-generated name will be created
3. No manual intervention required

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
This error should not occur anymore since we're using container image deployment.

**Previous Issue**: Local Python version didn't match Lambda's runtime (3.12).

**Current Solution**: The Lambda function is deployed as a container image built from `backend/lambda/Dockerfile`, which uses the official AWS Lambda Python 3.12 base image. This ensures perfect consistency with the Lambda runtime environment.

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
cd backend/infrastructure
sam build
sam deploy
```

(Run from your repository root directory)

Since we're using container image deployment, SAM will rebuild the Docker image with your changes. No additional flags needed - `samconfig.toml` handles everything.
