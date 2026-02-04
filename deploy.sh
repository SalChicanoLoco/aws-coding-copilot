#!/bin/bash

# ============================================
# AWS Coding Copilot - Deployment Script
# ============================================
# This script automates the complete deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="aws-coding-copilot"
REGION="us-east-1"
ENVIRONMENT="prod"

# ============================================
# HELPER FUNCTIONS
# ============================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    print_success "$1 is installed"
    return 0
}

# ============================================
# VALIDATION
# ============================================

print_header "Step 1: Validating Prerequisites"

# Check AWS CLI
if ! check_command aws; then
    print_error "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check SAM CLI
if ! check_command sam; then
    print_error "Please install SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity --region $REGION &> /dev/null; then
    print_error "AWS credentials not configured properly"
    print_info "Run: aws configure"
    exit 1
fi
print_success "AWS credentials configured"

# Check for Anthropic API key in SSM
print_info "Checking for Anthropic API key in SSM..."
if ! aws ssm get-parameter --name /prod/anthropic-api-key --region $REGION &> /dev/null; then
    print_error "Anthropic API key not found in SSM Parameter Store"
    print_info "Please create it with:"
    echo "  aws ssm put-parameter --name /prod/anthropic-api-key --value \"YOUR_KEY\" --type SecureString --region $REGION"
    exit 1
fi
print_success "Anthropic API key found in SSM"

# ============================================
# BUILD
# ============================================

print_header "Step 2: Building SAM Application"

cd backend/infrastructure

print_info "Running sam build..."
if sam build; then
    print_success "SAM build completed"
else
    print_error "SAM build failed"
    exit 1
fi

# ============================================
# DEPLOY BACKEND
# ============================================

print_header "Step 3: Deploying Backend to AWS"

print_info "Deploying stack: $STACK_NAME"

# Check if this is first deployment
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack exists, performing update..."
    if sam deploy --region $REGION; then
        print_success "Stack updated successfully"
    else
        print_error "Stack update failed"
        exit 1
    fi
else
    print_info "First deployment, running guided mode..."
    print_info "Please answer the prompts (use defaults for most options)"
    if sam deploy --guided --region $REGION; then
        print_success "Stack deployed successfully"
    else
        print_error "Stack deployment failed"
        exit 1
    fi
fi

cd ../..

# ============================================
# GET OUTPUTS
# ============================================

print_header "Step 4: Retrieving Stack Outputs"

print_info "Fetching stack outputs..."

API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
    --output text \
    --region $REGION)

BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
    --output text \
    --region $REGION)

DIST_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text \
    --region $REGION)

FRONTEND_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
    --output text \
    --region $REGION)

print_success "API Endpoint: $API_ENDPOINT"
print_success "S3 Bucket: $BUCKET_NAME"
print_success "CloudFront Distribution: $DIST_ID"
print_success "Frontend URL: $FRONTEND_URL"

# ============================================
# UPDATE FRONTEND CONFIG
# ============================================

print_header "Step 5: Configuring Frontend"

print_info "Updating API endpoint in frontend/app.js..."

# Check if endpoint is already configured
if grep -q "YOUR_API_ENDPOINT_HERE" frontend/app.js; then
    # macOS uses different sed syntax
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" frontend/app.js
    else
        sed -i "s|YOUR_API_ENDPOINT_HERE/chat|$API_ENDPOINT|g" frontend/app.js
    fi
    print_success "Frontend configured with API endpoint"
else
    print_info "API endpoint already configured"
fi

# ============================================
# DEPLOY FRONTEND
# ============================================

print_header "Step 6: Deploying Frontend to S3"

print_info "Syncing frontend files to S3..."
if aws s3 sync frontend/ s3://$BUCKET_NAME/ --delete --region $REGION; then
    print_success "Frontend deployed to S3"
else
    print_error "Frontend deployment failed"
    exit 1
fi

# ============================================
# INVALIDATE CLOUDFRONT
# ============================================

print_header "Step 7: Invalidating CloudFront Cache"

print_info "Creating CloudFront invalidation..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id $DIST_ID \
    --paths "/*" \
    --region $REGION \
    --query 'Invalidation.Id' \
    --output text)

print_success "Invalidation created: $INVALIDATION_ID"
print_info "Cache invalidation may take a few minutes to complete"

# ============================================
# FINAL STATUS
# ============================================

print_header "Deployment Complete!"

echo ""
echo -e "${GREEN}✓ Backend deployed successfully${NC}"
echo -e "${GREEN}✓ Frontend deployed successfully${NC}"
echo -e "${GREEN}✓ CloudFront cache invalidated${NC}"
echo ""
echo -e "${BLUE}Access your application:${NC}"
echo -e "  Frontend URL: ${GREEN}$FRONTEND_URL${NC}"
echo -e "  API Endpoint: ${GREEN}$API_ENDPOINT${NC}"
echo ""
echo -e "${YELLOW}Note: CloudFront may take 5-10 minutes to fully deploy${NC}"
echo -e "${YELLOW}You can also access via S3 directly while CloudFront deploys${NC}"
echo ""

# ============================================
# TESTING
# ============================================

print_header "Testing Backend"

print_info "Sending test request to API..."
TEST_RESPONSE=$(curl -s -X POST $API_ENDPOINT \
    -H "Content-Type: application/json" \
    -d '{
        "message": "Hello! Can you help me with AWS?",
        "conversationId": "test-deploy-'$(date +%s)'"
    }')

if echo "$TEST_RESPONSE" | grep -q "response"; then
    print_success "API test successful!"
else
    print_error "API test failed. Response:"
    echo "$TEST_RESPONSE"
fi

echo ""
print_success "Deployment completed successfully!"
echo -e "${BLUE}Open ${GREEN}$FRONTEND_URL${BLUE} in your browser to start using AWS Coding Copilot!${NC}"
echo ""
