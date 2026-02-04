# AWS Coding Copilot Deployment Guide

This guide provides step-by-step instructions for deploying the AWS Coding Copilot application.

## Table of Contents
- [Prerequisites](#prerequisites)
- [One-Command Deployment](#one-command-deployment)
- [Manual Deployment (Optional)](#manual-deployment-optional)
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

### One-Time Setup

1. **Configure AWS CLI** with your credentials:
   ```bash
   aws configure
   ```
   Set region to `us-east-1` for consistency.

2. **Store Anthropic API key** in AWS Systems Manager Parameter Store:
   ```bash
   aws ssm put-parameter --name /prod/anthropic-api-key \
     --value "sk-ant-..." --type SecureString --region us-east-1
   ```

3. **Verify setup**:
   ```bash
   aws sts get-caller-identity
   aws ssm get-parameter --name /prod/anthropic-api-key \
     --with-decryption --region us-east-1
   ```

## One-Command Deployment

Deploy everything with a single command:

```bash
./deploy.sh
```

That's it! 🚀

The script will:
- ✅ Validate prerequisites (AWS CLI, SAM CLI, API key)
- ✅ Build the Lambda function
- ✅ Deploy backend infrastructure to AWS
- ✅ Automatically configure the frontend with your API endpoint
- ✅ Deploy the frontend to S3
- ✅ Display your application URL

**First-time deployment**: The script will run `sam deploy --guided` and prompt you for configuration:
- **Stack Name**: `aws-coding-copilot` (press Enter)
- **AWS Region**: `us-east-1` (press Enter)
- **Confirm changes**: `y`
- **Allow SAM CLI IAM role creation**: `y`
- **Disable rollback**: `n` (press Enter)
- **CodingCopilotFunction has no authorization**: `y`
- **Save arguments**: `y` (press Enter)

**Subsequent deployments**: The script will automatically use saved settings.

## Manual Deployment (Optional)

If you prefer step-by-step control:

### Step 1: Build the Application

```bash
cd backend/infrastructure
sam build
```

### Step 2: Deploy Backend

For first deployment:
```bash
sam deploy --guided
```

For subsequent deployments:
```bash
sam deploy
```

### Step 3: Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

### Step 4: Update Frontend Configuration

```bash
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

cd ../../frontend
sed -i.bak "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" app.js
rm -f app.js.bak
```

### Step 5: Deploy Frontend to S3

```bash
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

aws s3 sync . s3://$BUCKET_NAME/ --delete --region us-east-1
```

### Step 6: Get Frontend URL

```bash
FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Frontend URL: $FRONTEND_URL"
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

1. Get your frontend URL:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name aws-coding-copilot \
     --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
     --output text \
     --region us-east-1
   ```

2. Open the URL in your browser
3. Type a message and verify you receive a response

### Verify DynamoDB

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

### Update Backend

```bash
./deploy.sh
```

Or manually:
```bash
cd backend/infrastructure
sam build
sam deploy
```

### Update Frontend Only

```bash
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

aws s3 sync frontend/ s3://$BUCKET_NAME/ --delete --region us-east-1
```

### View Lambda Logs

```bash
sam logs -n CodingCopilotFunction --stack-name aws-coding-copilot --tail
```

Or using AWS CLI:
```bash
aws logs tail /aws/lambda/prod-coding-copilot-chat --follow --region us-east-1
```

## Troubleshooting

### Issue: "Parameter /prod/anthropic-api-key not found"

**Solution**: Store the API key in SSM:
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_API_KEY" \
  --type SecureString \
  --region us-east-1
```

### Issue: CORS errors in browser

**Solution**: 
1. Check Lambda logs for errors
2. Verify the API Gateway CORS configuration in template.yaml
3. Clear browser cache and try again

### Issue: Frontend shows "API endpoint not configured"

**Solution**: Run the deployment script again, or manually update `frontend/app.js`:
```bash
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

sed -i.bak "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" frontend/app.js
```

### Issue: Lambda timeout errors

**Solution**: 
1. Check Lambda logs for specific errors
2. Verify Anthropic API is responding
3. Consider increasing Lambda timeout in template.yaml (currently 30s)

### Issue: S3 website not loading

**Solution**:
1. Verify bucket policy allows public read access
2. Check that website hosting is enabled
3. Ensure files were uploaded successfully:
   ```bash
   BUCKET_NAME=$(aws cloudformation describe-stacks \
     --stack-name aws-coding-copilot \
     --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
     --output text \
     --region us-east-1)
   
   aws s3 ls s3://$BUCKET_NAME/ --region us-east-1
   ```

## Cleanup

To delete all resources:

```bash
# Get bucket name before deleting stack
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

# Empty the S3 bucket first (required before stack deletion)
aws s3 rm s3://$BUCKET_NAME/ --recursive --region us-east-1

# Delete the CloudFormation stack
aws cloudformation delete-stack \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name aws-coding-copilot \
  --region us-east-1
```

Optionally, remove the API key:
```bash
aws ssm delete-parameter \
  --name /prod/anthropic-api-key \
  --region us-east-1
```

## Cost Estimation

Expected monthly costs for light usage (< 1000 requests/month):

- **S3**: ~$0.50 (storage + requests)
- **Lambda**: ~$0.20 (512MB, light usage)
- **API Gateway**: ~$0.10
- **DynamoDB**: ~$0.25 (PAY_PER_REQUEST, with TTL)
- **Anthropic API**: Variable (based on usage)

**Total AWS Infrastructure**: ~$1-2/month (excluding Anthropic API costs)

### Cost Optimization

- ✅ DynamoDB uses PAY_PER_REQUEST (no idle costs)
- ✅ 30-day TTL automatically deletes old conversations
- ✅ No VPC or NAT Gateway costs
- ✅ S3 website hosting is extremely cheap
- ✅ No CloudFront costs

## Support

For issues or questions:
1. Check CloudWatch Logs for Lambda errors
2. Review DynamoDB for stored conversations
3. Test API Gateway endpoint directly with curl
4. Open an issue on GitHub
