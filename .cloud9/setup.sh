#!/bin/bash
set -e

echo "=========================================="
echo "  AWS Coding Copilot - Cloud9 Setup"
echo "=========================================="
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade aws-sam-cli
npm install -g npm@latest

echo ""
echo "🔧 Configuring AWS region..."
aws configure set default.region us-east-2

echo ""
echo "📥 Cloning repository..."
if [ -d "aws-coding-copilot" ]; then
    echo "Repository already exists, updating..."
    cd aws-coding-copilot
    git pull
else
    git clone https://github.com/SalChicanoLoco/aws-coding-copilot.git
    cd aws-coding-copilot
fi

echo ""
echo "🚀 Auto-deploying..."
./deploy-safe.sh --yes

echo ""
echo "🔌 Integrating copilot into Cloud9 IDE..."
bash .cloud9/integrate.sh

echo ""
echo "=========================================="
echo "✅ Environment ready!"
echo "=========================================="
echo ""
echo "📡 API endpoint:"
aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text

echo ""
echo "🌐 Frontend URL:"
aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text

echo ""
echo "🤖 Launch copilot in Cloud9:"
echo "   ./copilot"
echo ""
echo "✨ You're all set! Open the Frontend URL in your browser or run ./copilot"
echo ""
