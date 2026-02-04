#!/bin/bash
set -e

echo "=========================================="
echo "🚀 AWS Coding Copilot - Complete Setup"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Deploy the Lambda function with the correct model"
echo "  2. Deploy the frontend to S3"
echo "  3. Create a Cloud9 development environment (optional)"
echo "  4. Test the deployment"
echo ""

REGION="${AWS_REGION:-us-east-2}"

# Step 1: Verify prerequisites
echo "📋 Step 1: Checking prerequisites..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI not found. Install: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ All prerequisites met"
echo ""

# Step 2: Deploy the Lambda and infrastructure
echo "🏗️  Step 2: Deploying Lambda and infrastructure..."
cd backend/infrastructure

echo "Building Lambda container..."
sam build --use-container

echo "Deploying to AWS..."
sam deploy --no-confirm-changeset --region $REGION

cd ../..
echo "✅ Backend deployed"
echo ""

# Step 3: Get outputs
echo "📡 Step 3: Retrieving deployment outputs..."
API_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text 2>/dev/null || echo "")

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text 2>/dev/null || echo "")

FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text 2>/dev/null || echo "")

echo "API URL: $API_URL"
echo "S3 Bucket: $BUCKET_NAME"
echo "Frontend URL: $FRONTEND_URL"
echo ""

# Step 4: Deploy frontend
echo "🎨 Step 4: Deploying frontend..."
cd frontend

# Update app.js with API endpoint
if [ ! -z "$API_URL" ]; then
    sed -i.bak "s|const API_ENDPOINT = '.*';|const API_ENDPOINT = '$API_URL';|" app.js
    rm -f app.js.bak
fi

# Upload to S3
aws s3 sync . s3://$BUCKET_NAME/ --delete --region $REGION
cd ..
echo "✅ Frontend deployed"
echo ""

# Step 5: Test the deployment
echo "🧪 Step 5: Testing deployment..."
if [ ! -z "$API_URL" ]; then
    RESPONSE=$(curl -s -X POST $API_URL \
      -H "Content-Type: application/json" \
      -d '{"message": "Hello, test deployment", "conversationId": "setup-test-'$(date +%s)'"}' || echo "")
    
    if echo "$RESPONSE" | grep -q "response"; then
        echo "✅ Lambda is responding correctly!"
        echo "Sample response: $(echo $RESPONSE | cut -c1-100)..."
    else
        echo "⚠️  Lambda response may have issues. Response:"
        echo "$RESPONSE" | head -c 500
        echo ""
    fi
fi
echo ""

# Step 6: Optional Cloud9 setup
echo "☁️  Step 6: Cloud9 environment (optional)..."
read -p "Do you want to create a Cloud9 development environment? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating Cloud9 environment with integrated copilot..."
    
    # Get the first available subnet
    SUBNET_ID=$(aws ec2 describe-subnets \
      --region $REGION \
      --query 'Subnets[0].SubnetId' \
      --output text 2>/dev/null || echo "")
    
    if [ -z "$SUBNET_ID" ]; then
        echo "❌ Could not find a subnet. Please create a Cloud9 environment manually."
    else
        echo "Using subnet: $SUBNET_ID"
        
        aws cloudformation create-stack \
          --stack-name coding-copilot-cloud9 \
          --template-body file://cloudformation/cloud9-environment.yaml \
          --parameters ParameterKey=SubnetId,ParameterValue=$SUBNET_ID \
          --region $REGION
        
        echo "Cloud9 environment is being created..."
        echo "Monitor progress: aws cloudformation describe-stacks --stack-name coding-copilot-cloud9 --region $REGION"
        echo ""
        
        echo "Waiting for stack creation (this may take 5-10 minutes)..."
        if aws cloudformation wait stack-create-complete --stack-name coding-copilot-cloud9 --region $REGION 2>/dev/null; then
            CLOUD9_URL=$(aws cloudformation describe-stacks \
              --stack-name coding-copilot-cloud9 \
              --region $REGION \
              --query 'Stacks[0].Outputs[?OutputKey==`Cloud9URL`].OutputValue' \
              --output text 2>/dev/null || echo "")
            
            echo "✅ Cloud9 environment created!"
            echo "URL: $CLOUD9_URL"
            echo ""
            echo "🔌 Next: Open Cloud9 and run:"
            echo "   bash .cloud9/setup.sh"
            echo ""
            echo "This will:"
            echo "   - Clone the repository"
            echo "   - Deploy the application"
            echo "   - Integrate the copilot into the IDE"
            echo "   - Give you a './copilot' command to launch it"
        else
            echo "⚠️  Stack creation may still be in progress. Check AWS Console for details."
        fi
    fi
else
    echo "Skipping Cloud9 environment creation"
fi
echo ""

# Step 7: Summary
echo "=========================================="
echo "✅ SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Frontend URL:"
echo "   $FRONTEND_URL"
echo ""
echo "📡 API Endpoint:"
echo "   $API_URL"
echo ""
echo "🎯 Next steps:"
echo "   1. Open the frontend URL in your browser"
echo "   2. Start chatting with your AWS Coding Copilot"
echo "   3. The AI uses claude-3-haiku-20240307 model"
echo ""
echo "📊 View logs:"
echo "   sam logs -n CodingCopilotFunction --stack-name prod-coding-copilot --tail --region $REGION"
echo ""
echo "🔄 To redeploy after changes:"
echo "   ./deploy-safe.sh --yes"
echo ""
