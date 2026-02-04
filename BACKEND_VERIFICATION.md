# Backend Verification Guide

## How to Check if Your Backend is Working

After deploying with `./deploy.sh`, use this guide to verify everything is working correctly.

## Quick Check

### 1. Frontend Shows Production Mode (Not Demo Mode)

**Before deployment:**
```
🎮 Demo Mode Active - You're seeing simulated responses
```

**After deployment (correct):**
- The demo mode indicator should be GONE
- Messages should come from real Claude AI
- Responses will be more varied and intelligent than demo responses

### 2. Test the Backend Directly

Get your API endpoint:
```bash
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text
```

Test with curl:
```bash
curl -X POST https://YOUR-ENDPOINT-HERE/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Generate a Python Lambda function that returns Hello World",
    "conversationId": "test-123"
  }'
```

**Expected response:**
```json
{
  "response": "Here's a Python Lambda function that returns Hello World...",
  "conversationId": "test-123",
  "timestamp": "2024-02-04T12:34:56.789Z"
}
```

## Detailed Verification Steps

### Step 1: Check CloudFormation Stack Status

```bash
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus' \
  --output text
```

**Expected:** `CREATE_COMPLETE` or `UPDATE_COMPLETE`

### Step 2: Verify Lambda Function Exists

```bash
aws lambda get-function \
  --function-name prod-coding-copilot-chat \
  --region us-east-1 \
  --query 'Configuration.FunctionName' \
  --output text
```

**Expected:** `prod-coding-copilot-chat`

### Step 3: Check Lambda Logs

```bash
# Get the log group
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/prod-coding-copilot-chat \
  --region us-east-1

# Get recent logs
aws logs tail /aws/lambda/prod-coding-copilot-chat \
  --follow \
  --region us-east-1
```

Make a request from the frontend and watch for log entries.

### Step 4: Check DynamoDB Table

```bash
aws dynamodb describe-table \
  --table-name prod-coding-copilot-conversations \
  --region us-east-1 \
  --query 'Table.TableStatus' \
  --output text
```

**Expected:** `ACTIVE`

### Step 5: Verify SSM Parameter

```bash
aws ssm get-parameter \
  --name /prod/anthropic-api-key \
  --region us-east-1 \
  --query 'Parameter.Name' \
  --output text
```

**Expected:** `/prod/anthropic-api-key`

### Step 6: Check Frontend Configuration

View the frontend source in your browser:
```
View → Developer → View Source
```

Look for:
```javascript
const API_ENDPOINT = 'https://....execute-api.us-east-1.amazonaws.com/prod/chat';
const DEMO_MODE = !API_ENDPOINT.startsWith('https://');
```

**Verify:**
- `API_ENDPOINT` is a real HTTPS URL (not 'YOUR_API_ENDPOINT_HERE')
- `DEMO_MODE` check is `!API_ENDPOINT.startsWith('https://')` (not includes)

## Common Issues

### Issue 1: Frontend Still in Demo Mode

**Symptoms:**
- Demo mode indicator still visible
- Getting simulated responses

**Check:**
```bash
# View deployed frontend JavaScript
curl https://YOUR-BUCKET-NAME.s3.amazonaws.com/app.js | head -20
```

If `API_ENDPOINT` is still `'YOUR_API_ENDPOINT_HERE'`, redeploy:
```bash
cd frontend
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

# Get API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

# Update app.js
sed -i.bak "s|YOUR_API_ENDPOINT_HERE|$API_ENDPOINT|g" app.js
rm -f app.js.bak

# Sync to S3
aws s3 sync . s3://$BUCKET/ --delete
```

### Issue 2: CORS Errors

**Symptoms:**
- Browser console shows CORS policy errors
- No response from backend

**Fix:** The SAM template includes CORS configuration. Redeploy backend:
```bash
cd backend/infrastructure
sam build
sam deploy
```

### Issue 3: Lambda Function Errors

**Check CloudWatch Logs:**
```bash
aws logs tail /aws/lambda/prod-coding-copilot-chat \
  --since 10m \
  --region us-east-1
```

**Common causes:**
- Missing or invalid Anthropic API key
- DynamoDB permissions issue
- Lambda timeout (increase in template.yaml)

### Issue 4: Anthropic API Key Not Found

**Symptoms:**
- Lambda logs show "Failed to initialize Anthropic client"
- 500 errors

**Fix:**
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value 'YOUR_ANTHROPIC_API_KEY' \
  --type SecureString \
  --region us-east-1 \
  --overwrite
```

## Testing End-to-End

### Test 1: Simple Request

Visit your frontend URL and ask:
```
"What is AWS Lambda?"
```

**Expected:** Detailed, intelligent response about AWS Lambda (not the demo response)

### Test 2: Code Generation

Ask:
```
"Generate a Python Lambda function that processes S3 events"
```

**Expected:** Contextual code with explanations (more sophisticated than demo)

### Test 3: Conversation History

Ask multiple related questions:
```
1. "Create a Lambda function that reads from S3"
2. "Add error handling to it"
3. "Add logging"
```

**Expected:** Each response builds on previous context

### Test 4: Direct API Call

```bash
curl -X POST https://YOUR-API-ENDPOINT/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Test message",
    "conversationId": "test-'$(date +%s)'"
  }' | jq
```

**Expected:** JSON response with `response`, `conversationId`, and `timestamp`

## Success Indicators

✅ Frontend loads without "Demo Mode Active" indicator
✅ Responses are varied and intelligent (not canned)
✅ Direct curl requests to API work
✅ Lambda logs show successful invocations
✅ DynamoDB table receives conversation data
✅ No CORS errors in browser console
✅ Conversation history works across multiple messages

## Need Help?

If issues persist after following this guide:

1. Check `TROUBLESHOOTING.md` for SSL/certificate issues
2. Review CloudWatch logs for detailed error messages
3. Verify all AWS resources are in the same region (us-east-1)
4. Ensure IAM permissions are correct
5. Check Anthropic API key is valid and has quota

## Monitoring Costs

Check your AWS bill:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-02-01,End=2024-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Expected monthly costs:**
- Lambda: ~$0.20
- API Gateway: ~$1.00
- DynamoDB: ~$0.25
- S3: ~$0.10
- **Total AWS: < $2/month**
- Anthropic API: Variable (pay-per-use)
