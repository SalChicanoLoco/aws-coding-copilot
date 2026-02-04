# AWS Coding Copilot - Agent Instructions

This file provides agent-specific instructions for GitHub Copilot coding agents working on this repository.

## Project Summary

AWS Coding Copilot is a self-deploying AI assistant that helps developers work with AWS services. It uses AWS Lambda (Python), API Gateway, DynamoDB, and S3 for a serverless architecture, powered by Anthropic's Claude API.

**Core Philosophy**: This tool must be able to deploy and validate itself reliably.

## Building the Project

### Prerequisites
- AWS CLI (v2.x+) configured with valid credentials
- SAM CLI (v1.100.0+) 
- Docker Desktop running (required for Lambda container builds)
- Anthropic API key stored in SSM Parameter Store at `/prod/anthropic-api-key`

### Build Commands

```bash
# Build the Lambda container (from repository root)
cd backend/infrastructure
sam build

# This will:
# - Use Docker to build the Lambda container image
# - Install Python dependencies from backend/lambda/requirements.txt
# - Take 2-3 minutes on first build
```

## Deploying the Project

### Primary Deployment

**ALWAYS use the safe deployment script:**

```bash
./deploy-safe.sh
```

This script:
- ✅ Validates all prerequisites (AWS CLI, SAM CLI, Docker)
- ✅ Detects and fixes region mismatches automatically
- ✅ Checks for orphaned S3 buckets from failed deployments
- ✅ Validates the Anthropic API key exists in SSM
- ✅ Builds the Lambda container image
- ✅ Deploys the CloudFormation stack via SAM
- ✅ Automatically configures the frontend with the API endpoint
- ✅ Uploads frontend files to S3
- ✅ Displays the application URL

**Expected deployment time**: 5-10 minutes for a fresh deployment.

### Legacy Deployment (Not Recommended)

```bash
./deploy.sh  # Less validation, more prone to errors
```

### Manual Deployment Steps

If you need fine-grained control:

```bash
# 1. Build
cd backend/infrastructure
sam build

# 2. Deploy backend
sam deploy --guided  # First time only
# OR
sam deploy  # Uses samconfig.toml

# 3. Configure and deploy frontend
# (This is automated in deploy-safe.sh)
```

## Testing the Project

### Automated Validation

```bash
./validate-self.sh
```

This comprehensive validation script:
- Checks CloudFormation stack status
- Retrieves and tests the API endpoint
- Sends a test message to the AI assistant
- Verifies the frontend is accessible
- Confirms end-to-end functionality

**Expected result**: All checks should pass with ✅ green checkmarks.

### Manual Testing

1. Get the frontend URL:
```bash
aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text \
  --region us-east-2
```

2. Open the URL in a browser
3. Type a message like "Generate a Python Lambda function"
4. Verify the AI responds appropriately

### Viewing Logs

```bash
# Real-time logs
sam logs -n CodingCopilotFunction --stack-name prod-coding-copilot --tail --region us-east-2

# Or via AWS CLI
aws logs tail /aws/lambda/CodingCopilotFunction --follow --region us-east-2
```

### No Automated Test Suite

**Important**: This project does not have unit tests, integration tests, or a test framework. Testing is done via:
- Deployment validation (`validate-self.sh`)
- Manual browser testing
- Log inspection

## Project Structure

```
aws-coding-copilot/
├── frontend/                   # Vanilla JavaScript static site
│   ├── index.html             # Main UI
│   ├── app.js                 # API communication logic
│   └── style.css              # Styles
├── backend/
│   ├── lambda/
│   │   ├── chat_handler.py   # Lambda function (main code)
│   │   ├── Dockerfile         # Container image definition
│   │   └── requirements.txt   # Python deps: boto3, anthropic
│   └── infrastructure/
│       ├── template.yaml      # SAM template (infrastructure)
│       ├── samconfig.toml     # SAM configuration
│       └── cleanup.sh         # Stack cleanup script
├── .github/
│   ├── copilot-instructions.md    # Repository-wide instructions
│   └── copilot-setup-steps.yaml   # Environment setup steps
├── deploy-safe.sh             # PRIMARY deployment script ⭐
├── deploy.sh                  # Legacy deployment script
├── validate-self.sh           # Validation script
└── *.md                       # Documentation
```

## Technology Stack

- **Frontend**: Vanilla JavaScript (no framework), HTML5, CSS3
- **Backend**: Python 3.12 in AWS Lambda (container-based)
- **API**: AWS API Gateway (REST API with CORS)
- **Database**: DynamoDB (PAY_PER_REQUEST, 30-day TTL)
- **Infrastructure**: AWS SAM (CloudFormation abstraction)
- **AI**: Anthropic Claude API
- **Deployment**: Docker + SAM CLI
- **Region**: us-east-2 (default)

## Common Issues and Solutions

### Issue: "Docker is not running"
**Solution**: 
```bash
# Start Docker Desktop, then verify:
docker info
```

### Issue: "Parameter /prod/anthropic-api-key not found"
**Solution**:
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "sk-ant-..." \
  --type SecureString \
  --region us-east-2
```

### Issue: Stack is stuck in ROLLBACK_COMPLETE
**Solution**:
```bash
cd backend/infrastructure
./cleanup.sh
cd ../..
./deploy-safe.sh
```

### Issue: "Early Validation" errors
**Cause**: Usually orphaned S3 buckets from previous failed deployments.
**Solution**: The `deploy-safe.sh` script detects and offers to clean these automatically.

### Issue: CORS errors in browser
**Solution**:
- Check Lambda returns proper CORS headers
- Verify API Gateway CORS configuration
- Clear browser cache

## Coding Patterns

### Python (Lambda)

**Required patterns**:
- All responses must include CORS headers
- Always use try-except for error handling
- Return proper status codes (200, 400, 500)
- Never hardcode secrets - use SSM Parameter Store

**Example Lambda response**:
```python
return {
    'statusCode': 200,
    'headers': {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    },
    'body': json.dumps({'response': 'value'})
}
```

### Infrastructure (SAM)

- Use container-based Lambda (not zip deployment)
- Set Lambda timeout to 30 seconds
- Use PAY_PER_REQUEST for DynamoDB (no provisioned capacity)
- Always enable CORS on API Gateway
- Use SSM Parameter Store for secrets

## Important Constraints

### DO NOT:
- ❌ Use `deploy.sh` - always use `deploy-safe.sh`
- ❌ Change the stack name (`prod-coding-copilot`)
- ❌ Store secrets in code
- ❌ Add heavy JavaScript frameworks
- ❌ Use provisioned capacity for DynamoDB
- ❌ Remove Docker requirement

### DO:
- ✅ Use `deploy-safe.sh` for deployments
- ✅ Test with `validate-self.sh` after changes
- ✅ Keep infrastructure minimal (cost target: <$2/month)
- ✅ Include CORS headers in all API responses
- ✅ Follow the existing vanilla JavaScript pattern
- ✅ Use container-based Lambda deployment

## Workflow for Making Changes

1. **Make code changes** in appropriate files
2. **Build**: `cd backend/infrastructure && sam build`
3. **Deploy**: `./deploy-safe.sh` (from repo root)
4. **Validate**: `./validate-self.sh`
5. **Check logs** if issues: `sam logs -n CodingCopilotFunction --tail`
6. **Test manually** by opening the frontend URL

## Cost and Performance

- **Target cost**: <$2/month for AWS infrastructure
- **Lambda**: 512MB memory, 30s timeout
- **API Gateway**: REST API (not HTTP API)
- **DynamoDB**: PAY_PER_REQUEST mode (no idle costs)
- **Data retention**: 30-day TTL on conversations

## Getting Help

- **Deployment issues**: See `DEPLOYMENT.md` and `TROUBLESHOOTING.md`
- **Architecture details**: See `README.md`
- **Self-validation**: Run `./validate-self.sh`
- **Recent changes**: See `CHANGELOG.md`
- **Vision/goals**: See `VISION.md`
