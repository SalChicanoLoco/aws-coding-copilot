# AWS Coding Copilot Deployment Guide

This guide provides step-by-step instructions for deploying the AWS Coding Copilot application.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Backend Deployment](#backend-deployment)
- [Frontend Deployment](#frontend-deployment)
- [Testing](#testing)
- [Updates and Maintenance](#updates-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

### Required Tools
- **AWS CLI**: Version 2.x or later
  ```bash
  aws --version
  ```
- **SAM CLI**: Version 1.100.0 or later
  ```bash
  sam --version
  ```
- **Anthropic API Key**: Required for AI functionality

### AWS Configuration
1. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   ```
   Set region to `us-east-1` for consistency.

2. Verify your configuration:
   ```bash
   aws sts get-caller-identity
   ```

## Initial Setup

### 1. Store Anthropic API Key

Store your Anthropic API key in AWS Systems Manager Parameter Store:

```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_ANTHROPIC_API_KEY_HERE" \
  --type SecureString \
  --region us-east-1
```

Verify the parameter was created:
```bash
aws ssm get-parameter \
  --name /prod/anthropic-api-key \
  --with-decryption \
  --region us-east-1
```

### 2. Clone Repository (if not already done)

```bash
git clone https://github.com/your-username/aws-coding-copilot.git
cd aws-coding-copilot
```

## Backend Deployment

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
- Validate prerequisites
- Build the SAM application
- Deploy to AWS
- Display all endpoints

### Option 2: Manual Deployment

#### Step 1: Build the Application

```bash
cd backend/infrastructure
sam build
```

#### Step 2: Deploy (First Time)

For the first deployment, use guided mode:

```bash
sam deploy --guided
```

Answer the prompts:
- **Stack Name**: `aws-coding-copilot`
- **AWS Region**: `us-east-1`
- **Parameter Environment**: `prod`
- **Parameter FrontendBucketName**: Press Enter (auto-generated)
- **Confirm changes before deploy**: `Y`
- **Allow SAM CLI IAM role creation**: `Y`
- **Disable rollback**: `N`
- **CodingCopilotFunction has no authorization**: `Y`
- **Save arguments to configuration file**: `Y`
- **SAM configuration file**: Press Enter (default)
- **SAM configuration environment**: Press Enter (default)

#### Step 3: Deploy (Subsequent Times)

After the first deployment, simply run:

```bash
sam deploy
```

#### Step 4: Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

Save these values - you'll need them for frontend deployment.

## Frontend Deployment

### Step 1: Update API Endpoint

Get the API endpoint from the stack outputs:

```bash
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

echo "API Endpoint: $API_ENDPOINT"
```

Update `frontend/app.js`:

```bash
# On macOS:
sed -i '' "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" frontend/app.js

# On Linux:
sed -i "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" frontend/app.js
```

Or manually edit `frontend/app.js` and replace:
```javascript
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE/chat';
```
with:
```javascript
const API_ENDPOINT = 'https://xxxxx.execute-api.us-east-1.amazonaws.com/prod/chat';
```

### Step 2: Deploy Frontend to S3

Get the bucket name and deploy:

```bash
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Deploying to bucket: $BUCKET_NAME"

aws s3 sync frontend/ s3://$BUCKET_NAME/ --delete --region us-east-1
```

### Step 3: Invalidate CloudFront Cache

```bash
DIST_ID=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Invalidating CloudFront distribution: $DIST_ID"

aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*" \
  --region us-east-1
```

### Step 4: Get Frontend URL

```bash
FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Frontend URL: $FRONTEND_URL"
echo "Open this URL in your browser!"
```

## Testing

### Test Backend API

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Generate a Python Lambda function that processes S3 events",
    "conversationId": "test-conv-123"
  }'
```

Expected response:
```json
{
  "response": "Here's a Python Lambda function...",
  "conversationId": "test-conv-123",
  "timestamp": "2024-01-01T12:00:00.000000"
}
```

### Test Frontend

1. Open the Frontend URL in your browser
2. Type a message like: "Generate a Python Lambda function that processes S3 events"
3. Click Send
4. Verify you receive a response

### Verify DynamoDB

Check that conversations are being stored:

```bash
TABLE_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ConversationsTableName`].OutputValue' \
  --output text \
  --region us-east-1)

aws dynamodb scan \
  --table-name $TABLE_NAME \
  --limit 5 \
  --region us-east-1
```

## Updates and Maintenance

### Update Backend Code

```bash
cd backend/infrastructure
sam build
sam deploy
```

### Update Frontend

```bash
# Make changes to frontend files
# Then sync to S3
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

aws s3 sync frontend/ s3://$BUCKET_NAME/ --delete --region us-east-1

# Invalidate CloudFront cache
DIST_ID=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text \
  --region us-east-1)

aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*" --region us-east-1
```

### View Lambda Logs

```bash
sam logs -n CodingCopilotFunction --stack-name aws-coding-copilot --tail
```

## Troubleshooting

### Issue: "Parameter /prod/anthropic-api-key not found"

**Solution**: Make sure the API key is stored in SSM:
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_API_KEY" \
  --type SecureString \
  --region us-east-1
```

### Issue: CORS errors in browser

**Solution**: 
1. Check that the Lambda function is returning proper CORS headers
2. Verify the API Gateway CORS configuration in the SAM template
3. Check browser console for specific error messages

### Issue: Frontend shows "API endpoint not configured"

**Solution**: Update the API_ENDPOINT in `frontend/app.js` with your actual API Gateway URL.

### Issue: CloudFront shows old content

**Solution**: Invalidate the CloudFront cache:
```bash
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
```

### Issue: Lambda timeout errors

**Solution**: 
1. Check Lambda logs for specific errors
2. Verify Anthropic API is responding
3. Consider increasing Lambda timeout in template.yaml

### Viewing Detailed Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/prod-coding-copilot-chat --follow --region us-east-1

# API Gateway logs
aws logs tail API-Gateway-Execution-Logs_xxxxx/prod --follow --region us-east-1
```

## Cleanup

To delete all resources:

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Note: S3 bucket must be empty before stack deletion
# If deletion fails due to non-empty bucket:
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

aws s3 rm s3://$BUCKET_NAME/ --recursive --region us-east-1

# Then retry stack deletion
```

Optionally, remove the SSM parameter:
```bash
aws ssm delete-parameter \
  --name /prod/anthropic-api-key \
  --region us-east-1
```

## Cost Estimation

Expected monthly costs for light usage (< 1000 requests/month):

- **Lambda**: < $0.50 (512MB, ~2s execution time)
- **API Gateway**: < $1.00 (< 1000 requests)
- **DynamoDB**: < $0.50 (PAY_PER_REQUEST, with TTL)
- **S3**: < $0.50 (storage + requests)
- **CloudFront**: < $1.00 (data transfer)
- **Anthropic API**: Variable (based on usage)

**Total AWS Infrastructure**: < $5/month (excluding Anthropic API costs)

To minimize costs:
- DynamoDB uses PAY_PER_REQUEST (no idle costs)
- 30-day TTL automatically deletes old data
- No VPC or NAT Gateway costs
- CloudFront PriceClass_100 (cheapest option)
- Can disable CloudFront and use S3 website directly to save ~$1/month

## Support

For issues or questions:
1. Check CloudWatch Logs for Lambda errors
2. Review DynamoDB for stored conversations
3. Test API Gateway endpoint directly with curl
4. Open an issue on GitHub
