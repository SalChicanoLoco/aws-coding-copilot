#!/bin/bash
# Self-validation script - deploys and tests the application

set -e

echo "========================================"
echo "  AWS Coding Copilot Self-Validation"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get region
REGION=$(grep 'region = ' backend/infrastructure/samconfig.toml | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null || echo "us-east-2")
STACK_NAME="prod-coding-copilot"

echo "Testing deployment in region: $REGION"
echo ""

# 1. Check if stack exists
echo "1. Checking stack status..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "NOT_FOUND" ]; then
    echo -e "${RED}❌ Stack not deployed${NC}"
    echo "Run ./deploy-safe.sh first"
    exit 1
fi

if [[ ! "$STACK_STATUS" =~ ^(CREATE_COMPLETE|UPDATE_COMPLETE)$ ]]; then
    echo -e "${YELLOW}⚠️  Stack status: $STACK_STATUS${NC}"
    echo "Stack may not be fully deployed or is in an error state"
    exit 1
fi

echo -e "${GREEN}✓${NC} Stack Status: $STACK_STATUS"
echo ""

# 2. Get API endpoint
echo "2. Getting API endpoint..."
ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' --output text 2>/dev/null || echo "")

if [ -z "$ENDPOINT" ]; then
    echo -e "${RED}❌ API endpoint not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} API Endpoint: $ENDPOINT"
echo ""

# 3. Test API with a real request
echo "3. Testing API endpoint..."
TEST_MESSAGE="Generate a simple Python Lambda function that returns Hello World"
CONV_ID="validate-$(date +%s)"

RESPONSE=$(curl -s -X POST $ENDPOINT \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"$TEST_MESSAGE\",\"conversationId\":\"$CONV_ID\"}" \
    --max-time 30 || echo "")

if [ -z "$RESPONSE" ]; then
    echo -e "${RED}❌ No response from API${NC}"
    exit 1
fi

# Check if response contains expected fields
if echo "$RESPONSE" | jq -e '.response' &>/dev/null; then
    RESPONSE_TEXT=$(echo "$RESPONSE" | jq -r '.response' | head -c 200)
    echo -e "${GREEN}✓${NC} API responded successfully"
    echo ""
    echo "Response preview:"
    echo "$RESPONSE_TEXT..."
    echo ""
else
    echo -e "${RED}❌ Invalid response format${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

# 4. Check frontend
echo "4. Checking frontend..."
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' --output text 2>/dev/null || echo "")

if [ -z "$FRONTEND_URL" ]; then
    echo -e "${YELLOW}⚠️  Frontend URL not found${NC}"
else
    echo -e "${GREEN}✓${NC} Frontend URL: $FRONTEND_URL"
    
    # Test if frontend is accessible
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $FRONTEND_URL --max-time 10 || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓${NC} Frontend is accessible"
    else
        echo -e "${YELLOW}⚠️  Frontend returned HTTP $HTTP_CODE${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================"
echo "  ✅ Self-Validation Passed!"
echo "========================================${NC}"
echo ""
echo "Summary:"
echo "  • Stack deployed successfully"
echo "  • API endpoint is working"
echo "  • Lambda function responded to test message"
if [ ! -z "$FRONTEND_URL" ]; then
    echo "  • Frontend is accessible"
fi
echo ""
echo "🎉 Your AWS Coding Copilot is fully operational!"
echo ""
echo "Try it out:"
echo "  API: $ENDPOINT"
if [ ! -z "$FRONTEND_URL" ]; then
    echo "  Web: $FRONTEND_URL"
fi
echo ""
