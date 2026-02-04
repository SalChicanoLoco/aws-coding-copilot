#!/bin/bash
set -e  # Exit on any error

REGION="us-east-1"
STACK_NAME="aws-coding-copilot"

echo "=========================================="
echo "AWS Coding Copilot - Automated Deployment"
echo "=========================================="
echo ""

# Step 1: Validate prerequisites
echo "✓ Step 1/6: Validating prerequisites..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI not found. Install: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

# Check API key exists
if ! aws ssm get-parameter --name /prod/anthropic-api-key --region $REGION --with-decryption &> /dev/null; then
    echo "❌ Anthropic API key not found in SSM Parameter Store."
    echo "   Run: aws ssm put-parameter --name /prod/anthropic-api-key --value 'YOUR_KEY' --type SecureString --region $REGION"
    exit 1
fi

echo "   ✓ AWS CLI installed"
echo "   ✓ SAM CLI installed"
echo "   ✓ API key found in SSM"
echo ""

# Step 2: Build Lambda
echo "✓ Step 2/6: Building Lambda function..."
cd backend/infrastructure
sam build --region $REGION
echo ""

# Step 3: Deploy backend
echo "✓ Step 3/6: Deploying backend infrastructure..."
if [ ! -f samconfig.toml ]; then
    echo "   First deployment - running guided setup..."
    sam deploy --guided --region $REGION
else
    sam deploy --region $REGION
fi
echo ""

# Step 4: Get outputs
echo "✓ Step 4/6: Retrieving deployment outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text)

echo "   API Endpoint: $API_ENDPOINT"
echo "   S3 Bucket: $BUCKET_NAME"
echo "   Frontend URL: $FRONTEND_URL"
echo ""

# Step 5: Update frontend with API endpoint
echo "✓ Step 5/6: Updating frontend configuration..."
cd ../../frontend
# Replace placeholder with actual API endpoint
sed -i.bak "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" app.js
rm -f app.js.bak
echo "   ✓ API endpoint configured in frontend"
echo ""

# Step 6: Deploy frontend to S3
echo "✓ Step 6/6: Deploying frontend to S3..."
aws s3 sync . s3://$BUCKET_NAME/ --delete --region $REGION
echo ""

echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Your AWS Coding Copilot is live at:"
echo "   $FRONTEND_URL"
echo ""
echo "🔧 API Endpoint:"
echo "   $API_ENDPOINT"
echo ""
echo "📝 Test backend with:"
echo "   curl -X POST $API_ENDPOINT \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"message\":\"Generate a Python Lambda function\"}'"
echo ""
echo "💰 Estimated cost: <\$2/month (excluding Anthropic API usage)"
echo "=========================================="
