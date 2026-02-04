#!/bin/bash
# Cleanup script for failed deployments

set -e

echo "========================================"
echo "  AWS Coding Copilot Cleanup"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get region
REGION=$(grep 'region = ' samconfig.toml | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null || echo "us-east-2")
STACK_NAME="prod-coding-copilot"

echo "Region: $REGION"
echo "Stack: $STACK_NAME"
echo ""

# Check if stack exists
echo "Checking stack status..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "NOT_FOUND" ]; then
    echo -e "${YELLOW}⚠️  Stack does not exist${NC}"
else
    echo "Stack Status: $STACK_STATUS"
    echo ""
    
    # Get S3 bucket name if stack exists
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' --output text 2>/dev/null || echo "")
    
    if [ ! -z "$BUCKET_NAME" ]; then
        echo "Found S3 Bucket: $BUCKET_NAME"
        echo "Emptying bucket..."
        aws s3 rm s3://$BUCKET_NAME/ --recursive --region $REGION 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Bucket emptied"
        echo ""
    fi
    
    # Delete the stack
    echo "Deleting CloudFormation stack..."
    aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
    echo ""
    echo "Waiting for stack deletion..."
    echo "(This may take a few minutes)"
    
    if aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Stack deleted successfully"
    else
        echo -e "${YELLOW}⚠️  Stack deletion may have issues. Check the AWS Console.${NC}"
    fi
fi

echo ""

# Check for any orphaned S3 buckets
echo "Checking for orphaned S3 buckets..."
ORPHANED=$(aws s3 ls --region $REGION 2>/dev/null | grep -i "coding-copilot" || echo "")

if [ ! -z "$ORPHANED" ]; then
    echo -e "${YELLOW}⚠️  Found potential orphaned buckets:${NC}"
    echo "$ORPHANED"
    echo ""
    read -p "Delete these buckets? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$ORPHANED" | awk '{print $3}' | while read bucket; do
            echo "Emptying $bucket..."
            aws s3 rm "s3://$bucket" --recursive --region $REGION 2>/dev/null || true
            echo "Deleting $bucket..."
            aws s3 rb "s3://$bucket" --region $REGION 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Processed $bucket"
        done
    fi
else
    echo -e "${GREEN}✓${NC} No orphaned buckets found"
fi

echo ""
echo -e "${GREEN}========================================"
echo "  Cleanup Complete"
echo "========================================${NC}"
echo ""
echo "You can now run a fresh deployment:"
echo "./deploy-safe.sh"
echo ""
