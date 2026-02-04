#!/bin/bash
# Simple one-command deployment script
# Run this after merging the PR: ./quick-deploy.sh

set -e

echo "🚀 Quick Deploy - CORS Fix"
echo "================================"
echo ""

# Check we're in the right place
if [ ! -f "backend/infrastructure/template.yaml" ]; then
    echo "❌ Error: Run from repository root"
    exit 1
fi

# Region
REGION="${AWS_REGION:-us-east-1}"
echo "📍 Using region: $REGION"
echo ""

# Build
echo "🔨 Building Lambda..."
cd backend/infrastructure
sam build --region "$REGION"

# Deploy
echo "📦 Deploying to AWS..."
sam deploy --region "$REGION" --no-confirm-changeset

# Get endpoints
echo ""
echo "📡 Getting endpoints..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region "$REGION")

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region "$REGION")

FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text \
  --region "$REGION")

echo "API Endpoint: $API_ENDPOINT"
echo "S3 Bucket: $BUCKET_NAME"

# Update frontend
echo ""
echo "🎨 Updating frontend..."
cd ../../frontend
sed -i.bak "s|YOUR_API_ENDPOINT_HERE|$API_ENDPOINT|g" app.js
rm -f app.js.bak

# Deploy frontend
echo "☁️  Uploading to S3..."
aws s3 sync . s3://$BUCKET_NAME/ --delete --region "$REGION"

# Test CORS
echo ""
echo "🧪 Testing CORS..."
CORS_TEST=$(curl -s -X OPTIONS "$API_ENDPOINT" -H "Origin: http://example.com" -H "Access-Control-Request-Method: POST" -I | grep -i "access-control-allow-origin" || echo "")

if [ -n "$CORS_TEST" ]; then
    echo "✅ CORS headers detected!"
else
    echo "⚠️  Could not verify CORS headers (but might still work)"
fi

# Done
echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Frontend URL:"
echo "   $FRONTEND_URL"
echo ""
echo "📡 API Endpoint:"
echo "   $API_ENDPOINT"
echo ""
echo "🎯 Next steps:"
echo "   1. Open the frontend URL in your browser"
echo "   2. Open Dev Tools (F12) → Network tab"
echo "   3. Send a message"
echo "   4. Verify no CORS errors appear"
echo ""
echo "📊 View logs:"
echo "   aws logs tail /aws/lambda/prod-coding-copilot-chat --follow --region $REGION"
echo ""
