#!/bin/bash
# Pre-deployment validation and safe deployment script
set -e

echo "========================================"
echo "  AWS Coding Copilot Safe Deployment"
echo "========================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check AWS credentials
echo "📋 Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓${NC} AWS Account: $ACCOUNT_ID"
echo ""

# 2. Get AWS CLI default region
CLI_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$CLI_REGION" ]; then
    echo -e "${YELLOW}⚠️  No default region configured in AWS CLI${NC}"
    CLI_REGION="us-east-2"
    echo "Setting default region to us-east-2..."
    aws configure set region us-east-2
fi
echo -e "${GREEN}✓${NC} AWS CLI Region: $CLI_REGION"
echo ""

# 3. Check samconfig.toml region
SAM_REGION=$(grep 'region = ' backend/infrastructure/samconfig.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo -e "${GREEN}✓${NC} SAM Config Region: $SAM_REGION"
echo ""

# 4. Warn if mismatch
if [ "$CLI_REGION" != "$SAM_REGION" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Region mismatch detected!${NC}"
    echo "   AWS CLI: $CLI_REGION"
    echo "   SAM Config: $SAM_REGION"
    echo ""
    read -p "   Update samconfig.toml to use $CLI_REGION? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create backup
        cp backend/infrastructure/samconfig.toml backend/infrastructure/samconfig.toml.bak
        # Update both region lines (works on both Linux and macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/region = \".*\"/region = \"$CLI_REGION\"/g" backend/infrastructure/samconfig.toml
        else
            # Linux
            sed -i "s/region = \".*\"/region = \"$CLI_REGION\"/g" backend/infrastructure/samconfig.toml
        fi
        echo -e "${GREEN}✓${NC} Updated samconfig.toml to $CLI_REGION (backup saved as samconfig.toml.bak)"
        SAM_REGION=$CLI_REGION
    else
        echo "Continuing with region mismatch. Deployment may fail."
    fi
    echo ""
fi

# 5. Check for orphaned resources
echo "🔍 Checking for orphaned resources..."
ORPHANED_BUCKETS=$(aws s3 ls --region $SAM_REGION 2>/dev/null | grep -i "coding-copilot" || echo "")
if [ ! -z "$ORPHANED_BUCKETS" ]; then
    echo -e "${YELLOW}⚠️  Found S3 buckets that may be orphaned:${NC}"
    echo "$ORPHANED_BUCKETS"
    echo ""
    read -p "   Delete these buckets? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$ORPHANED_BUCKETS" | awk '{print $3}' | while read bucket; do
            echo "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive --region $SAM_REGION 2>/dev/null || true
            echo "Deleting bucket: $bucket"
            aws s3 rb "s3://$bucket" --region $SAM_REGION 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Processed $bucket"
        done
        echo ""
    fi
else
    echo -e "${GREEN}✓${NC} No orphaned buckets found"
fi
echo ""

# 6. Check Docker
echo "🐳 Checking Docker..."
if ! docker info &>/dev/null; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker is running"
echo ""

# 7. Check for SAM CLI
echo "📦 Checking SAM CLI..."
if ! command -v sam &>/dev/null; then
    echo -e "${RED}❌ SAM CLI is not installed${NC}"
    echo "Install from: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi
SAM_VERSION=$(sam --version)
echo -e "${GREEN}✓${NC} SAM CLI installed: $SAM_VERSION"
echo ""

# 8. Check for Anthropic API key
echo "🔑 Checking Anthropic API key..."
if aws ssm get-parameter --name /prod/anthropic-api-key --region $SAM_REGION &>/dev/null; then
    echo -e "${GREEN}✓${NC} Anthropic API key found in SSM"
    
    # Test the API key by making a minimal API call
    echo "🧪 Testing API key validity..."
    API_KEY=$(aws ssm get-parameter --name /prod/anthropic-api-key --region $SAM_REGION --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
    
    if [ ! -z "$API_KEY" ]; then
        # Test with a minimal request using curl
        TEST_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://api.anthropic.com/v1/messages \
            -H "x-api-key: $API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{
                "model": "claude-3-haiku-20240307",
                "max_tokens": 10,
                "messages": [{"role": "user", "content": "test"}]
            }' 2>&1)
        
        HTTP_CODE=$(echo "$TEST_RESPONSE" | tail -1)
        RESPONSE_BODY=$(echo "$TEST_RESPONSE" | sed '$d')
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}✓${NC} API key is valid and working"
        elif [ "$HTTP_CODE" = "401" ]; then
            echo -e "${RED}❌ API key is invalid or expired${NC}"
            echo ""
            echo "Please update your API key:"
            echo "aws ssm put-parameter --name /prod/anthropic-api-key \\"
            echo "  --value \"sk-ant-...\" --type SecureString --region $SAM_REGION --overwrite"
            exit 1
        elif echo "$RESPONSE_BODY" | grep -q "credit balance is too low"; then
            echo -e "${YELLOW}⚠️  WARNING: Anthropic API account has insufficient credits${NC}"
            echo ""
            echo "Your API key is valid, but your account is out of credits."
            echo "Add credits at: https://console.anthropic.com/settings/billing"
            echo ""
            read -p "Continue with deployment anyway? (y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        elif [ "$HTTP_CODE" = "429" ]; then
            echo -e "${YELLOW}⚠️  WARNING: Rate limit reached${NC}"
            echo "API key appears valid but rate limited. Deployment can continue."
        else
            echo -e "${YELLOW}⚠️  Could not fully validate API key (HTTP $HTTP_CODE)${NC}"
            echo "Deployment will continue, but Lambda may fail at runtime."
            echo "Response: $RESPONSE_BODY" | head -c 200
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠️  Could not retrieve API key value for testing${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Anthropic API key not found in SSM Parameter Store${NC}"
    echo ""
    echo "To set it up, run:"
    echo "aws ssm put-parameter --name /prod/anthropic-api-key \\"
    echo "  --value \"sk-ant-...\" --type SecureString --region $SAM_REGION"
    echo ""
    read -p "Continue without API key? (Deployment will work but Lambda will fail at runtime) (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# 9. Deploy
echo "========================================"
echo "  Starting Deployment"
echo "========================================"
echo ""
cd backend/infrastructure

echo "Building Lambda container image..."
if ! sam build; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

echo "Deploying..."
if ! sam deploy --region $SAM_REGION; then
    echo ""
    echo -e "${RED}========================================"
    echo "  Deployment Failed"
    echo "========================================${NC}"
    echo ""
    echo "To see CloudFormation events:"
    echo "aws cloudformation describe-stack-events --stack-name prod-coding-copilot --region $SAM_REGION --max-items 10"
    echo ""
    echo "To delete a failed stack:"
    echo "aws cloudformation delete-stack --stack-name prod-coding-copilot --region $SAM_REGION"
    exit 1
fi

cd ../..

# 10. Post-deployment validation
echo ""
echo -e "${GREEN}========================================"
echo "  Deployment Successful!"
echo "========================================${NC}"
echo ""

# Get outputs
ENDPOINT=$(aws cloudformation describe-stacks --stack-name prod-coding-copilot --region $SAM_REGION --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' --output text 2>/dev/null || echo "")
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name prod-coding-copilot --region $SAM_REGION --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' --output text 2>/dev/null || echo "")
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name prod-coding-copilot --region $SAM_REGION --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' --output text 2>/dev/null || echo "")

if [ ! -z "$ENDPOINT" ]; then
    echo "📡 API Endpoint: $ENDPOINT"
fi

if [ ! -z "$BUCKET_NAME" ]; then
    echo "📦 S3 Bucket: $BUCKET_NAME"
    echo ""
    echo "Updating frontend with API endpoint..."
    
    # Update app.js with the actual endpoint
    if [ ! -z "$ENDPOINT" ]; then
        sed "s|const API_ENDPOINT = '.*';|const API_ENDPOINT = '$ENDPOINT';|" frontend/app.js > /tmp/app.js
        cp /tmp/app.js frontend/app.js
    fi
    
    # Upload frontend to S3
    echo "Uploading frontend files to S3..."
    aws s3 sync frontend/ s3://$BUCKET_NAME/ --delete --region $SAM_REGION
    echo -e "${GREEN}✓${NC} Frontend uploaded"
fi

echo ""
if [ ! -z "$FRONTEND_URL" ]; then
    echo -e "${GREEN}🚀 Application URL: $FRONTEND_URL${NC}"
else
    echo "Application deployed successfully!"
fi
echo ""
echo "Next steps:"
echo "1. Open the application URL in your browser"
echo "2. Start chatting with your AWS Coding Copilot!"
echo ""
