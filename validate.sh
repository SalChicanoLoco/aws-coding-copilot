#!/bin/bash

# ============================================
# AWS Coding Copilot - Validation Script
# ============================================
# This script validates that all prerequisites are met before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REGION="us-east-1"
ERRORS=0

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
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================
# CHECK TOOLS
# ============================================

print_header "Checking Required Tools"

# AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    print_success "AWS CLI installed (version $AWS_VERSION)"
else
    print_error "AWS CLI not installed"
    print_info "Install: https://aws.amazon.com/cli/"
fi

# SAM CLI
if command -v sam &> /dev/null; then
    SAM_VERSION=$(sam --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    print_success "SAM CLI installed (version $SAM_VERSION)"
else
    print_error "SAM CLI not installed"
    print_info "Install: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
fi

# Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    print_success "Git installed (version $GIT_VERSION)"
else
    print_warning "Git not installed (optional)"
fi

# curl
if command -v curl &> /dev/null; then
    print_success "curl installed"
else
    print_warning "curl not installed (useful for testing)"
fi

# ============================================
# CHECK AWS CONFIGURATION
# ============================================

print_header "Checking AWS Configuration"

# AWS credentials
if aws sts get-caller-identity --region $REGION &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text --region $REGION)
    print_success "AWS credentials configured"
    print_info "Account ID: $ACCOUNT_ID"
    print_info "User/Role: $USER_ARN"
else
    print_error "AWS credentials not configured"
    print_info "Run: aws configure"
fi

# Default region
CONFIGURED_REGION=$(aws configure get region)
if [ "$CONFIGURED_REGION" == "$REGION" ]; then
    print_success "Default region is $REGION"
else
    print_warning "Default region is $CONFIGURED_REGION (should be $REGION)"
    print_info "Run: aws configure set region $REGION"
fi

# ============================================
# CHECK SSM PARAMETER
# ============================================

print_header "Checking Anthropic API Key"

if aws ssm get-parameter --name /prod/anthropic-api-key --region $REGION &> /dev/null; then
    print_success "Anthropic API key exists in SSM Parameter Store"
    
    # Check if it's encrypted
    PARAM_TYPE=$(aws ssm get-parameter \
        --name /prod/anthropic-api-key \
        --region $REGION \
        --query 'Parameter.Type' \
        --output text)
    
    if [ "$PARAM_TYPE" == "SecureString" ]; then
        print_success "API key is encrypted (SecureString)"
    else
        print_warning "API key is not encrypted (Type: $PARAM_TYPE)"
    fi
else
    print_error "Anthropic API key not found in SSM"
    print_info "Create it with:"
    echo "  aws ssm put-parameter --name /prod/anthropic-api-key --value \"YOUR_KEY\" --type SecureString --region $REGION"
fi

# ============================================
# VALIDATE SAM TEMPLATE
# ============================================

print_header "Validating SAM Template"

if [ -f "backend/infrastructure/template.yaml" ]; then
    print_success "SAM template file exists"
    
    cd backend/infrastructure
    
    if sam validate --region $REGION &> /dev/null; then
        print_success "SAM template is valid"
    else
        print_error "SAM template validation failed"
        sam validate --region $REGION
    fi
    
    cd ../..
else
    print_error "SAM template not found at backend/infrastructure/template.yaml"
fi

# ============================================
# CHECK FRONTEND FILES
# ============================================

print_header "Checking Frontend Files"

if [ -f "frontend/index.html" ]; then
    print_success "index.html exists"
else
    print_error "frontend/index.html not found"
fi

if [ -f "frontend/app.js" ]; then
    print_success "app.js exists"
    
    # Check if API endpoint is configured
    if grep -q "YOUR_API_ENDPOINT_HERE" frontend/app.js; then
        print_warning "API endpoint not configured in app.js (will be updated during deployment)"
    else
        print_success "API endpoint appears to be configured"
    fi
else
    print_error "frontend/app.js not found"
fi

if [ -f "frontend/style.css" ]; then
    print_success "style.css exists"
else
    print_error "frontend/style.css not found"
fi

# ============================================
# CHECK BACKEND FILES
# ============================================

print_header "Checking Backend Files"

if [ -f "backend/lambda/chat_handler.py" ]; then
    print_success "Lambda handler exists"
else
    print_error "backend/lambda/chat_handler.py not found"
fi

if [ -f "backend/lambda/requirements.txt" ]; then
    print_success "requirements.txt exists"
    
    # Check for required packages
    if grep -q "anthropic" backend/lambda/requirements.txt; then
        print_success "anthropic package in requirements"
    else
        print_error "anthropic package missing from requirements.txt"
    fi
    
    if grep -q "boto3" backend/lambda/requirements.txt; then
        print_success "boto3 package in requirements"
    else
        print_warning "boto3 package missing (included in Lambda runtime)"
    fi
else
    print_error "backend/lambda/requirements.txt not found"
fi

# ============================================
# CHECK IAM PERMISSIONS
# ============================================

print_header "Checking IAM Permissions"

print_info "Testing CloudFormation permissions..."
if aws cloudformation list-stacks --region $REGION &> /dev/null; then
    print_success "CloudFormation permissions OK"
else
    print_error "Insufficient CloudFormation permissions"
fi

print_info "Testing S3 permissions..."
if aws s3 ls --region $REGION &> /dev/null; then
    print_success "S3 permissions OK"
else
    print_error "Insufficient S3 permissions"
fi

print_info "Testing Lambda permissions..."
if aws lambda list-functions --region $REGION &> /dev/null; then
    print_success "Lambda permissions OK"
else
    print_error "Insufficient Lambda permissions"
fi

print_info "Testing DynamoDB permissions..."
if aws dynamodb list-tables --region $REGION &> /dev/null; then
    print_success "DynamoDB permissions OK"
else
    print_error "Insufficient DynamoDB permissions"
fi

print_info "Testing API Gateway permissions..."
if aws apigateway get-rest-apis --region $REGION &> /dev/null; then
    print_success "API Gateway permissions OK"
else
    print_error "Insufficient API Gateway permissions"
fi

# ============================================
# CHECK EXISTING STACK
# ============================================

print_header "Checking Existing Deployment"

STACK_NAME="aws-coding-copilot"

if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].StackStatus' \
        --output text \
        --region $REGION)
    
    print_info "Stack '$STACK_NAME' exists with status: $STACK_STATUS"
    
    if [[ "$STACK_STATUS" == *"COMPLETE"* ]]; then
        print_success "Stack is in a stable state"
    elif [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
        print_warning "Stack operation in progress"
    elif [[ "$STACK_STATUS" == *"FAILED"* ]]; then
        print_error "Stack is in failed state"
    fi
else
    print_info "No existing stack found (this will be a new deployment)"
fi

# ============================================
# SUMMARY
# ============================================

print_header "Validation Summary"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}You are ready to deploy.${NC}"
    echo ""
    echo -e "${BLUE}To deploy, run:${NC}"
    echo -e "  ${GREEN}./deploy.sh${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found${NC}"
    echo -e "${RED}Please fix the errors above before deploying.${NC}"
    echo ""
    exit 1
fi
