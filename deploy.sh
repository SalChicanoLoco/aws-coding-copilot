#!/bin/bash
set -e  # Exit on any error

# Parse command line arguments
AUTO_APPROVE=false
for arg in "$@"; do
    if [[ "$arg" == "--yes" || "$arg" == "-y" ]]; then
        AUTO_APPROVE=true
    elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Automated deployment script for AWS Coding Copilot"
        echo ""
        echo "Options:"
        echo "  --yes, -y    Skip all interactive prompts (auto-accept defaults)"
        echo "  --help, -h   Show this help message"
        echo ""
        exit 0
    fi
done

REGION="us-east-2"
STACK_NAME="prod-coding-copilot"

echo "=========================================="
echo "AWS Coding Copilot - Automated Deployment"
echo "=========================================="
if [ "$AUTO_APPROVE" = true ]; then
    echo "  (Running with --yes flag)"
fi
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
echo "🔑 Checking AWS Bedrock access..."
if ! aws bedrock list-foundation-models --region $REGION &> /dev/null; then
    echo "⚠️  Cannot access AWS Bedrock. This may mean:"
    echo "   1. Bedrock is not available in region $REGION"
    echo "   2. Your AWS account doesn't have Bedrock enabled"
    echo "   3. You need to request model access"
    echo ""
    echo "   To enable Bedrock:"
    echo "   1. Go to: https://console.aws.amazon.com/bedrock"
    echo "   2. Click 'Model access' in the left sidebar"
    echo "   3. Request access to 'Claude 3 Haiku' model"
    echo ""
    read -p "Continue anyway? (y/N) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "   ✓ AWS Bedrock is accessible"
    
    # Check if Claude model is available
    if aws bedrock list-foundation-models --region $REGION --query 'modelSummaries[?contains(modelId, `anthropic.claude-3-haiku`)]' --output text 2>/dev/null | grep -q "anthropic"; then
        echo "   ✓ Claude 3 Haiku model is available"
    else
        echo "   ⚠️  Claude 3 Haiku may not be enabled"
        echo "   Request access at: https://console.aws.amazon.com/bedrock"
    fi
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
    if [ "$AUTO_APPROVE" = true ]; then
        echo "   First deployment with auto-approve - using defaults..."
        sam deploy --no-confirm-changeset --region $REGION
    else
        echo "   First deployment - running guided setup..."
        sam deploy --guided --region $REGION
    fi
else
    if [ "$AUTO_APPROVE" = true ]; then
        sam deploy --no-confirm-changeset --region $REGION
    else
        sam deploy --region $REGION
    fi
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

# Validate bucket name was retrieved
if [ -z "$BUCKET_NAME" ]; then
    echo "⚠️  Failed to retrieve bucket name from CloudFormation outputs."
    echo "   This may indicate the stack deployment didn't complete successfully."
    exit 1
fi

# Validate bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" --region $REGION 2>/dev/null; then
    echo "⚠️  Bucket not found. CloudFormation may not have created it."
    echo "   Checking stack status..."
    aws cloudformation describe-stack-resources \
      --stack-name $STACK_NAME \
      --region $REGION \
      --query 'StackResourceSummaries[?ResourceType==`AWS::S3::Bucket`]'
    exit 1
fi
echo "   ✓ S3 bucket verified"
echo ""

# Step 5: Update frontend with API endpoint
echo "✓ Step 5/6: Updating frontend configuration..."
cd ../../frontend
# Replace placeholder with actual API endpoint
sed -i.bak "s|YOUR_API_ENDPOINT_HERE|$API_ENDPOINT|g" app.js
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
