#!/bin/bash
# Pre-deployment validation and safe deployment script
# Usage: ./deploy-safe.sh [--yes|-y]
#   --yes, -y : Skip all interactive prompts (auto-accept defaults)
set -e

# Parse command line arguments
SKIP_PROMPTS=false
for arg in "$@"; do
    if [[ "$arg" == "--yes" || "$arg" == "-y" ]]; then
        SKIP_PROMPTS=true
    elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Safe deployment script with validation checks"
        echo ""
        echo "Options:"
        echo "  --yes, -y    Skip all interactive prompts (auto-accept defaults)"
        echo "  --help, -h   Show this help message"
        echo ""
        exit 0
    fi
done

echo "========================================"
echo "  AWS Coding Copilot Safe Deployment"
echo "========================================"
if [ "$SKIP_PROMPTS" = true ]; then
    echo "  (Running with --yes flag)"
fi
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check AWS credentials
echo "[CHECK] Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}[X] AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}[OK]${NC} AWS Account: $ACCOUNT_ID"
echo ""

# 2. Get AWS CLI default region
CLI_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$CLI_REGION" ]; then
    echo -e "${YELLOW}[WARNING]  No default region configured in AWS CLI${NC}"
    CLI_REGION="us-east-2"
    echo "Setting default region to us-east-2..."
    aws configure set region us-east-2
fi
echo -e "${GREEN}[OK]${NC} AWS CLI Region: $CLI_REGION"
echo ""

# 3. Check samconfig.toml region
SAM_REGION=$(grep 'region = ' backend/infrastructure/samconfig.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo -e "${GREEN}[OK]${NC} SAM Config Region: $SAM_REGION"
echo ""

# 4. Warn if mismatch
if [ "$CLI_REGION" != "$SAM_REGION" ]; then
    echo -e "${YELLOW}[WARNING]  WARNING: Region mismatch detected!${NC}"
    echo "   AWS CLI: $CLI_REGION"
    echo "   SAM Config: $SAM_REGION"
    echo ""
    
    UPDATE_REGION=false
    if [ "$SKIP_PROMPTS" = true ]; then
        echo "   Auto-updating samconfig.toml to use $CLI_REGION (--yes flag)"
        UPDATE_REGION=true
    else
        read -p "   Update samconfig.toml to use $CLI_REGION? (Y/n) " -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            UPDATE_REGION=true
        fi
    fi
    
    if [ "$UPDATE_REGION" = true ]; then
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
        echo -e "${GREEN}[OK]${NC} Updated samconfig.toml to $CLI_REGION (backup saved as samconfig.toml.bak)"
        SAM_REGION=$CLI_REGION
    else
        echo "Continuing with region mismatch. Deployment may fail."
    fi
    echo ""
fi

# 5. Check for orphaned resources
echo "[SCAN] Checking for orphaned resources..."
ORPHANED_BUCKETS=$(aws s3 ls --region $SAM_REGION 2>/dev/null | grep -i "coding-copilot" || echo "")
if [ ! -z "$ORPHANED_BUCKETS" ]; then
    echo -e "${YELLOW}[WARNING]  Found S3 buckets that may be orphaned:${NC}"
    echo "$ORPHANED_BUCKETS"
    echo ""
    
    DELETE_BUCKETS=false
    if [ "$SKIP_PROMPTS" = true ]; then
        echo "   Auto-deleting orphaned buckets (--yes flag)"
        DELETE_BUCKETS=true
    else
        read -p "   Delete these buckets? (Y/n) " -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            DELETE_BUCKETS=true
        fi
    fi
    
    if [ "$DELETE_BUCKETS" = true ]; then
        echo "$ORPHANED_BUCKETS" | awk '{print $3}' | while read bucket; do
            echo "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive --region $SAM_REGION 2>/dev/null || true
            echo "Deleting bucket: $bucket"
            aws s3 rb "s3://$bucket" --region $SAM_REGION 2>/dev/null || true
            echo -e "${GREEN}[OK]${NC} Processed $bucket"
        done
        echo ""
    fi
else
    echo -e "${GREEN}[OK]${NC} No orphaned buckets found"
fi
echo ""

# 6. Check Docker
echo "[DOCKER] Checking Docker..."
if ! docker info &>/dev/null; then
    echo -e "${RED}[X] Docker is not running${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Docker is running"
echo ""

# 7. Check for SAM CLI
echo "[PACKAGE] Checking SAM CLI..."
if ! command -v sam &>/dev/null; then
    echo -e "${RED}[X] SAM CLI is not installed${NC}"
    echo "Install from: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi
SAM_VERSION=$(sam --version)
echo -e "${GREEN}[OK]${NC} SAM CLI installed: $SAM_VERSION"
echo ""

# 8. Check for AWS Bedrock access
echo "[KEY] Checking AWS Bedrock access..."
BEDROCK_CHECK=$(aws bedrock list-foundation-models --region $SAM_REGION 2>&1 || echo "ERROR")

if echo "$BEDROCK_CHECK" | grep -q "ERROR\|AccessDenied\|not available"; then
    echo -e "${YELLOW}[WARNING]  Cannot access AWS Bedrock${NC}"
    echo ""
    echo "AWS Bedrock may not be enabled in your account or region."
    echo ""
    echo "To enable AWS Bedrock:"
    echo "1. Visit: https://console.aws.amazon.com/bedrock"
    echo "2. Click 'Model access' in the left sidebar"  
    echo "3. Click 'Manage model access'"
    echo "4. Enable 'Claude 3 Haiku' by Anthropic"
    echo "5. Submit the request (usually approved instantly)"
    echo ""
    
    if [ "$SKIP_PROMPTS" = true ]; then
        echo "   Continuing without Bedrock verification (--yes flag)"
        echo "   Lambda will fail at runtime if Bedrock is not enabled"
    else
        read -p "Continue without Bedrock verification? (Lambda will fail at runtime) (y/N) " -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${GREEN}[OK]${NC} AWS Bedrock is accessible"
    
    # Check if Claude model is available
    if echo "$BEDROCK_CHECK" | grep -q "anthropic.claude-3-haiku"; then
        echo -e "${GREEN}[OK]${NC} Claude 3 Haiku model is available"
    else
        echo -e "${YELLOW}[WARNING]  Claude 3 Haiku model may not be enabled${NC}"
        echo "Enable it at: https://console.aws.amazon.com/bedrock"
        
        if [ "$SKIP_PROMPTS" = false ]; then
            read -p "Continue anyway? (y/N) " -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
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
    echo -e "${RED}[X] Build failed${NC}"
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
    echo "[API] API Endpoint: $ENDPOINT"
fi

if [ ! -z "$BUCKET_NAME" ]; then
    echo "[PACKAGE] S3 Bucket: $BUCKET_NAME"
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
    echo -e "${GREEN}[OK]${NC} Frontend uploaded"
fi

echo ""
if [ ! -z "$FRONTEND_URL" ]; then
    echo -e "${GREEN}[LAUNCH] Application URL: $FRONTEND_URL${NC}"
else
    echo "Application deployed successfully!"
fi
echo ""
echo "Next steps:"
echo "1. Open the application URL in your browser"
echo "2. Start chatting with your AWS Coding Copilot!"
echo ""
