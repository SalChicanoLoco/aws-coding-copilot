# 🚀 AWS Coding Copilot

## 🔒 **SECURITY FIRST**

**⚠️ NEVER commit API keys to git!**

This project uses secure API key management:
- 📖 **New to this repo?** Read [SECURITY_SETUP.md](SECURITY_SETUP.md) first
- 🔐 Store API keys in AWS SSM Parameter Store (not in code)
- 🛡️ Security tools included: git-secrets, pre-commit hooks, automated scanning
- ⚡ Quick setup: Run `./setup-security.sh` after cloning

See [SECURITY.md](SECURITY.md) for complete security best practices.

---

> **Status**: Stack deployed successfully on AWS! ✅  
> **Next**: Building Render version for simpler deployment

## Quick Links
- [Complete Development Journey](JOURNEY.md) - How we got here
- [Project Vision](VISION.md) - Where we're going
- [Render Migration Plan](RENDER_MIGRATION_PLAN.md) - Next steps

## What This Is

An AI-powered AWS development assistant that can deploy and run itself. Built with Claude 3.5 Sonnet, it helps developers:
- Generate Lambda functions
- Create SAM templates
- Debug AWS deployments
- Optimize costs
- Learn AWS faster

**Philosophy**: If a tool for building AWS apps can't deploy itself reliably, it can't be trusted to help others.

## Two Versions

### 1. AWS Version (Current) - Serverless
**Cost**: ~$1-2/month + Anthropic API  
**Best for**: AWS developers, production use  
**Status**: ✅ Deployed and working

See [AWS Deployment Guide](backend/infrastructure/DEPLOYMENT_INSTRUCTIONS.md)

### 2. Render Version (Coming Soon) - Web Service
**Cost**: $7/month + Anthropic API  
**Best for**: Beginners, quick setup  
**Status**: 🚧 In development

See [Render Migration Plan](RENDER_MIGRATION_PLAN.md)

## The Isomorphic Vision

This tool demonstrates **isomorphic development**:
- ✅ Deploys itself
- ✅ Tests itself
- ✅ Documents itself
- ✅ Fixes itself
- ⏳ Runs on multiple platforms

[Read the full vision](VISION.md)

---

**Your AI-powered assistant for AWS development**

AWS Coding Copilot is a production-ready AI coding assistant that helps developers work with AWS services. Built with AWS Lambda, API Gateway, DynamoDB, and powered by Anthropic's Claude AI, it provides expert guidance on Lambda functions, SAM templates, AWS SDK code, deployment troubleshooting, and cost optimization.

## ✨ Features

- **Expert AWS Guidance**: Get help with Lambda functions, CloudFormation, SAM templates, and more
- **Multi-Language Support**: Python, Node.js, and other AWS SDK languages
- **Conversation History**: Maintains context across questions (30-day retention)
- **Fast & Scalable**: Serverless architecture with pay-per-use pricing
- **Container-Native**: Lambda deployed as container image for consistency and flexibility
- **Secure**: API keys stored in SSM Parameter Store, encrypted at rest
- **Cost-Effective**: < $5/month for light usage (excluding Anthropic API costs)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  User Browser                                                     │
│  ┌──────────────────┐                                            │
│  │  Static Website  │                                            │
│  │  (HTML/CSS/JS)   │                                            │
│  └────────┬─────────┘                                            │
│           │                                                       │
└───────────┼───────────────────────────────────────────────────────┘
            │
            │ HTTPS
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  AWS Cloud (us-east-2)                                           │
│                                                                   │
│  ┌───────────────┐                           ┌──────────────┐   │
│  │  S3 Bucket    │                           │     SSM      │   │
│  │  (Frontend)   │                           │  Parameter   │   │
│  │ Static Website│                           │    Store     │   │
│  └───────────────┘                           │  (API Key)   │   │
│                                               └──────┬───────┘   │
│  ┌───────────────┐      ┌──────────────┐           │           │
│  │  API Gateway  │──────│    Lambda    │───────────┘           │
│  │   REST API    │      │   Function   │                        │
│  └───────────────┘      │ (Container)  │                        │
│                          │ Python 3.12  │                        │
│                          └──────┬───────┘                        │
│                                 │                                │
│                                 ▼                                │
│                          ┌──────────────┐                        │
│                          │   DynamoDB   │                        │
│                          │ Conversations│                        │
│                          └──────────────┘                        │
│                                 │                                │
│                          ┌──────▼───────┐                        │
│                          │  Anthropic   │                        │
│                          │     API      │                        │
│                          └──────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
1. AWS CLI configured: `aws configure`
2. Docker Desktop running
3. SAM CLI installed: `brew install aws-sam-cli`
4. Anthropic API key in SSM Parameter Store:
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "sk-ant-..." \
  --type SecureString
```

### Deploy Everything
```bash
./deploy-safe.sh
```

That's it! The script will:
- ✓ Validate your AWS setup
- ✓ Check for orphaned resources
- ✓ Build Lambda with Docker
- ✓ Deploy infrastructure
- ✓ Deploy frontend
- ✓ Give you the live URL

## 🔄 What's Next?

Once AWS Copilot is running, **use it to build the IDE and coding agent**:

1. Open the deployed app
2. Ask it: "Help me add a code editor component"
3. Ask it: "Generate a Lambda function for file storage"
4. Ask it: "Create SAM template for the IDE backend"

**The tool helps build itself!** This is the isomorphic vision. 🔄

That's it! 🚀

**What deploy-safe.sh does:**
- ✅ Validates AWS credentials and Docker
- ✅ Detects and fixes region mismatches automatically
- ✅ Checks for and cleans up orphaned resources
- ✅ Validates Anthropic API key exists
- ✅ Builds Lambda container image with Docker
- ✅ Deploys infrastructure to AWS
- ✅ Automatically configures the frontend with API endpoint
- ✅ Uploads frontend to S3
- ✅ Displays your application URL

### Alternative: Legacy Deployment

```bash
./deploy.sh  # Original deployment script (less validation)
```

### Validate Your Deployment

Test that everything works end-to-end:

```bash
./validate-self.sh
```

This will:
- ✅ Check stack deployment status
- ✅ Test the API endpoint with a real message
- ✅ Verify frontend accessibility
- ✅ Confirm the app is fully operational

### Cleanup Failed Deployments

If something goes wrong:

```bash
cd backend/infrastructure
./cleanup.sh
```

Then try deploying again with `./deploy-safe.sh`.

### Manual Deployment

If you prefer step-by-step control, see [backend/infrastructure/DEPLOYMENT_INSTRUCTIONS.md](backend/infrastructure/DEPLOYMENT_INSTRUCTIONS.md) for detailed instructions.

## 📁 Project Structure

```
aws-coding-copilot/
├── frontend/
│   ├── index.html          # Main HTML page
│   ├── app.js              # JavaScript application logic
│   └── style.css           # Styles
├── backend/
│   ├── lambda/
│   │   ├── chat_handler.py # Lambda function
│   │   ├── requirements.txt # Python dependencies
│   │   └── Dockerfile      # Lambda container image
│   └── infrastructure/
│       └── template.yaml    # SAM template
├── deploy-safe.sh          # Safe deployment script
├── validate-self.sh        # Deployment validation
├── DEPLOYMENT.md           # Detailed deployment guide
└── README.md               # This file
```

## 🛠️ Usage Examples

Once deployed, you can ask the copilot questions like:

- "Generate a Python Lambda function that processes S3 events"
- "Create a SAM template for a REST API with DynamoDB"
- "Show me how to use boto3 to query DynamoDB"
- "What are best practices for Lambda error handling?"
- "How can I optimize costs for my DynamoDB table?"
- "Write a CloudFormation template for an S3 bucket with encryption"

## 🧪 Testing

### Test the Backend API

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Generate a Python Lambda function that processes S3 events",
    "conversationId": "test-123"
  }'
```

### Test the Frontend

1. Get your frontend URL:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name aws-coding-copilot \
     --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
     --output text \
     --region us-east-1
   ```

2. Open the URL in your browser
3. Start chatting with the AI assistant!

## 💰 Cost Estimate

Based on light usage (< 1,000 requests/month):

| Service | Monthly Cost |
|---------|--------------|
| S3 (storage + requests) | ~$0.50 |
| Lambda (512MB, ~2s/request) | ~$0.20 |
| API Gateway | ~$0.10 |
| DynamoDB (PAY_PER_REQUEST) | ~$0.25 |
| **Total AWS Infrastructure** | **~$1-2** |
| Anthropic API (variable) | Based on usage |

### Cost Optimization Tips

- ✅ DynamoDB uses PAY_PER_REQUEST (no idle costs)
- ✅ 30-day TTL automatically deletes old conversations
- ✅ No VPC or NAT Gateway costs
- ✅ S3 website hosting is extremely cheap
- ✅ No CloudFront costs

## 🔒 Security Features

- **Encrypted API Keys**: Stored as SecureString in SSM Parameter Store
- **CORS Protection**: Configured headers prevent unauthorized access
- **IAM Least Privilege**: Lambda only has permissions it needs
- **Data Retention**: 30-day TTL on conversation history
- **HTTPS Only**: All communication encrypted in transit

## 🐛 Troubleshooting

### Common Issues

**"Region mismatch" warning**
```bash
# The deploy-safe.sh script will detect this automatically and offer to fix it
# Or manually update your AWS CLI region:
aws configure set region us-east-2
```

**"Parameter /prod/anthropic-api-key not found"**
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_KEY" \
  --type SecureString \
  --region us-east-2
```

**"Early Validation" errors during deployment**
```bash
# Usually caused by orphaned S3 buckets from previous failed deployments
# The deploy-safe.sh script will detect and offer to clean these automatically
# Or manually check and clean:
aws s3 ls | grep coding-copilot
aws s3 rb s3://BUCKET-NAME --force --region us-east-2
```

**"Docker is not running"**
- Start Docker Desktop and wait for it to fully start
- Verify with: `docker info`
- **Note**: Docker is required for container image deployment. The Lambda function is packaged as a Docker container for better consistency and flexibility.

**"Image build failed"**
- Ensure Docker has enough disk space
- Check that the Dockerfile in `backend/lambda/` is valid
- Verify Python dependencies in `requirements.txt` are installable
- Run `sam build` manually to see detailed error messages

**CORS errors in browser**
- Check API Gateway CORS configuration
- Verify Lambda returns proper CORS headers
- Clear browser cache

**"API endpoint not configured"**
- Run `./deploy-safe.sh` again to reconfigure frontend

**S3 website not loading**
- Verify bucket policy allows public read access
- Check that website hosting is enabled
- Ensure frontend files were uploaded

**Stack is stuck in ROLLBACK_COMPLETE**
```bash
cd backend/infrastructure
./cleanup.sh
# Then redeploy:
cd ../..
./deploy-safe.sh
```

For more troubleshooting, see [backend/infrastructure/DEPLOYMENT_INSTRUCTIONS.md](backend/infrastructure/DEPLOYMENT_INSTRUCTIONS.md).

## 📚 Additional Documentation

- [Detailed Deployment Guide](DEPLOYMENT.md)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [Anthropic API Documentation](https://docs.anthropic.com/)

## 🔄 Updates and Maintenance

### Update Backend

```bash
cd backend/infrastructure
sam build
sam deploy
```

### Update Frontend

```bash
# Update files in frontend/
# Then sync to S3
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

aws s3 sync frontend/ s3://$BUCKET/ --delete --region us-east-1
```

### View Logs

```bash
sam logs -n CodingCopilotFunction --stack-name aws-coding-copilot --tail
```

## 🧹 Cleanup

To remove all resources:

```bash
# Get bucket name first
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text \
  --region us-east-1)

# Empty S3 bucket (required before stack deletion)
aws s3 rm s3://$BUCKET_NAME/ --recursive --region us-east-1

# Delete the CloudFormation stack
aws cloudformation delete-stack \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-delete-complete \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Optionally remove the API key
aws ssm delete-parameter \
  --name /prod/anthropic-api-key \
  --region us-east-1
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built with [AWS SAM](https://aws.amazon.com/serverless/sam/)
- Powered by [Anthropic Claude](https://www.anthropic.com/)
- Deployed on [AWS](https://aws.amazon.com/)

---

**Need help?** Check out the [Troubleshooting Guide](DEPLOYMENT.md#troubleshooting) or open an issue on GitHub.
