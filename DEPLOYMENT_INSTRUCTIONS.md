# Deployment Instructions for Model Fix

## Changes Made

The following files have been updated to use the correct Anthropic model (`claude-3-haiku-20240307`):

1. **backend/lambda/chat_handler.py** (line 281)
   - Changed from: `model="claude-3-5-sonnet-20241022"`
   - Changed to: `model="claude-3-haiku-20240307"`

2. **deploy.sh** (line 43)
   - Updated model name in API key validation test

3. **deploy-safe.sh** (line 131)
   - Updated model name in API key validation test

## Deployment Steps

### Option 1: Using deploy-safe.sh (Recommended)

```bash
cd /path/to/aws-coding-copilot
./deploy-safe.sh
```

This script will:
- ✅ Validate prerequisites (AWS CLI, SAM CLI, Docker)
- ✅ Test the Anthropic API key
- ✅ Build the Lambda container image
- ✅ Deploy the CloudFormation stack
- ✅ Configure and upload the frontend

### Option 2: Manual Deployment

```bash
# 1. Build the Lambda function
cd backend/infrastructure
sam build

# 2. Deploy the backend
sam deploy --region us-east-2

# 3. Get the API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

# 4. Update and deploy frontend
cd ../../frontend
sed -i.bak "s|YOUR_API_ENDPOINT_HERE|$API_ENDPOINT|g" app.js
rm -f app.js.bak

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

aws s3 sync . s3://$BUCKET_NAME/ --delete --region us-east-2
```

## Testing the Fix

### 1. Test the API Endpoint Directly

```bash
# Get your API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

# Send a test request
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello! Are you working now?", "conversationId": "test-haiku"}'
```

**Expected Response:**
- Should return a JSON object with a "response" field containing actual Claude text
- Should NOT contain errors about model not found

### 2. Check Lambda Logs

```bash
sam logs -n CodingCopilotFunction \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --tail
```

**What to Look For:**
- ✅ No `model: not_found_error` messages
- ✅ Successful API calls to Anthropic
- ✅ Response generation messages

### 3. Test the Frontend

1. Get the frontend URL:
```bash
FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text)

echo "Open: $FRONTEND_URL"
```

2. Open the URL in your browser
3. Type a message like: "Generate a Python Lambda function"
4. Verify you receive an actual AI response

## Success Criteria

After deployment, verify:
- ✅ Lambda uses `claude-3-haiku-20240307` model
- ✅ API calls to Anthropic succeed (check logs)
- ✅ Frontend receives actual AI responses (test in browser)
- ✅ No more `model: not_found_error` in CloudWatch logs

## Troubleshooting

### If deployment fails:

1. **Check Docker is running:**
   ```bash
   docker info
   ```

2. **Verify AWS credentials:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Check API key is valid:**
   ```bash
   aws ssm get-parameter \
     --name /prod/anthropic-api-key \
     --region us-east-2 \
     --with-decryption
   ```

4. **View CloudFormation events:**
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name prod-coding-copilot \
     --region us-east-2 \
     --max-items 20
   ```

### If Lambda still fails after deployment:

1. Check the CloudWatch logs for the actual error
2. Verify the model name in the deployed Lambda code
3. Test the Anthropic API key directly with curl (see problem statement)

## Model Information

- **Old Model (doesn't work):** `claude-3-5-sonnet-20241022`
- **New Model (working):** `claude-3-haiku-20240307`
- **API Key Location:** SSM Parameter Store at `/prod/anthropic-api-key` in `us-east-2`
- **API Key Credits:** $5.00 available

The `claude-3-haiku-20240307` model has been verified to work with the current API key tier.
