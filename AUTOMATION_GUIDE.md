# 🚀 Full Automation Guide - AWS Coding Copilot

## What's New: ZERO Manual Steps Required!

This update brings **complete automation** to AWS Coding Copilot with three major improvements:

### 1. 🔑 AWS Bedrock Integration (No More API Key Management!)
**The Big Win:** AWS already has your Anthropic keys through Bedrock!

- ✅ No more storing API keys in SSM Parameter Store
- ✅ No more managing API credits separately
- ✅ Native AWS integration with IAM permissions
- ✅ Access to Claude 3 Haiku model directly through AWS
- ✅ Billing integrated with your AWS account

### 2. 🤖 Cloud9 IDE Integration
**Work with the copilot while you code!**

- ✅ Embedded copilot interface in Cloud9
- ✅ One command to launch: `./copilot`
- ✅ Keep it open in a tab alongside your code
- ✅ Ask questions without leaving your IDE

### 3. ⚡ Full Automation Support
**User can literally leave and it deploys itself!**

- ✅ All scripts support `--yes` flag (no prompts)
- ✅ GitHub Actions auto-deploy on merge to main
- ✅ One-command setup script: `./setup-everything.sh`
- ✅ Cloud9 auto-setup script

---

## Quick Start Options

### Option 1: Complete Setup (Recommended)
```bash
./setup-everything.sh
```
This single command will:
1. Deploy Lambda with Bedrock
2. Deploy frontend to S3
3. Test the deployment
4. Optionally create Cloud9 environment

### Option 2: Deploy Only
```bash
./deploy-safe.sh --yes
```
Deploys without any prompts - perfect for automation!

### Option 3: Cloud9 IDE Setup
```bash
# In a new Cloud9 environment, run:
bash .cloud9/setup.sh

# This will:
# - Install dependencies
# - Clone the repo
# - Deploy everything
# - Integrate copilot into IDE
# - Give you a `./copilot` command
```

### Option 4: GitHub Actions (Auto-Deploy on Merge)
Just push to main branch - GitHub Actions will:
1. Build the Lambda container
2. Deploy to AWS
3. Update frontend
4. Test the deployment

---

## AWS Bedrock Setup

### First-Time Bedrock Setup (One-Time)

1. **Enable Bedrock Model Access:**
   - Visit: https://console.aws.amazon.com/bedrock
   - Click "Model access" in the left sidebar
   - Click "Manage model access"
   - Find "Claude 3 Haiku" by Anthropic
   - Check the box and click "Request model access"
   - Usually approved instantly!

2. **Verify Access:**
   ```bash
   aws bedrock list-foundation-models --region us-east-2 \
     --query 'modelSummaries[?contains(modelId, `anthropic.claude-3-haiku`)]'
   ```

3. **That's it!** No API keys to manage, no separate billing.

### What Changed

**Before (Anthropic API):**
```python
# Required anthropic library
import anthropic

# Required API key in SSM
client = anthropic.Anthropic(api_key=api_key)

# Called external API
response = client.messages.create(
    model="claude-3-haiku-20240307",
    ...
)
```

**After (AWS Bedrock):**
```python
# Only boto3 needed (already included)
import boto3

# No API key needed - uses IAM
bedrock = boto3.client('bedrock-runtime')

# Called through AWS
response = bedrock.invoke_model(
    modelId='anthropic.claude-3-haiku-20240307-v1:0',
    ...
)
```

### Benefits of Bedrock

✅ **Simpler Setup** - No separate API account needed  
✅ **IAM Integration** - Use standard AWS permissions  
✅ **Unified Billing** - Part of your AWS bill  
✅ **Regional Availability** - Deploy in any Bedrock-enabled region  
✅ **No External Dependencies** - Pure AWS solution  
✅ **Better Security** - No secrets to manage  

---

## Cloud9 IDE Integration

### What You Get

Once integrated, you can:

1. **Launch copilot with one command:**
   ```bash
   ./copilot
   ```

2. **Or use the launch script:**
   ```bash
   bash .copilot/launch.sh
   ```

3. **Or preview in Cloud9:**
   - Preview → Preview File → `.copilot/index.html`

### Files Created

```
your-workspace/
├── .copilot/
│   ├── index.html       # Integrated copilot interface
│   ├── launch.sh        # Launcher script
│   ├── copilot          # Quick access command
│   └── README.md        # Documentation
└── copilot              # Root-level shortcut
```

### Usage Examples

**In Cloud9 terminal:**
```bash
# Launch copilot
./copilot

# Ask while coding:
# "Generate a Lambda function that processes S3 events"
# "Create a SAM template for API Gateway + DynamoDB"
# "Help debug this CloudFormation error: [paste error]"
```

---

## Automation Features

### 1. No-Prompt Deployment

All scripts now support `--yes` flag:

```bash
# No questions asked
./deploy-safe.sh --yes
./deploy.sh --yes
./quick-deploy.sh --yes

# Even cleanup
cd backend/infrastructure
./cleanup.sh --yes
```

### 2. GitHub Actions Workflow

Located at: `.github/workflows/auto-deploy.yml`

**Triggers on:** Push to `main` branch

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Setup:**
```bash
# In your GitHub repo, add secrets:
# Settings → Secrets and variables → Actions → New repository secret

# Add:
# - AWS_ACCESS_KEY_ID: Your AWS access key
# - AWS_SECRET_ACCESS_KEY: Your AWS secret key
```

**What it does:**
1. Checks out code
2. Sets up Python and SAM CLI
3. Builds Lambda container
4. Deploys to AWS
5. Updates frontend
6. Tests the deployment
7. Outputs URLs

### 3. Complete Setup Script

**`setup-everything.sh`** does everything:

```bash
#!/bin/bash
./setup-everything.sh

# This will:
# ✅ Check prerequisites (AWS CLI, SAM, Docker)
# ✅ Build Lambda container
# ✅ Deploy to AWS with Bedrock
# ✅ Deploy frontend to S3
# ✅ Test the deployment
# ✅ Optionally create Cloud9 environment
# ✅ Show you all the URLs
```

### 4. Cloud9 Auto-Setup

**`.cloud9/setup.sh`** for Cloud9 environments:

```bash
bash .cloud9/setup.sh

# This will:
# ✅ Install SAM CLI and dependencies
# ✅ Configure AWS region (us-east-2)
# ✅ Clone/update repository
# ✅ Deploy with --yes flag
# ✅ Integrate copilot into IDE
# ✅ Give you `./copilot` command
```

---

## Migration from Anthropic API

If you were using the old version with direct Anthropic API:

### What's Removed

- ❌ No more `anthropic` Python library in `requirements.txt`
- ❌ No more API key in SSM Parameter Store (`/prod/anthropic-api-key`)
- ❌ No more SSM permissions in Lambda IAM role
- ❌ No more API key validation in deployment scripts
- ❌ No more external API calls

### What's Added

- ✅ Bedrock IAM permissions in Lambda
- ✅ Bedrock runtime client in Python
- ✅ Bedrock model access checks in deployment
- ✅ Pure AWS solution

### Migration Steps

**If you already have it deployed:**

1. **Enable Bedrock model access** (see above)

2. **Redeploy with new version:**
   ```bash
   git pull
   ./deploy-safe.sh --yes
   ```

3. **Test it:**
   ```bash
   ./validate-self.sh
   ```

4. **Clean up old API key** (optional):
   ```bash
   aws ssm delete-parameter \
     --name /prod/anthropic-api-key \
     --region us-east-2
   ```

---

## Cost Comparison

### Anthropic API (Old)
- Pay per token to Anthropic
- Separate billing account
- Pre-purchase credits
- **Estimated:** ~$0.01 per 1000 tokens

### AWS Bedrock (New)
- Pay per token through AWS
- Integrated with AWS bill
- Pay as you go
- **Claude 3 Haiku:** $0.00025 per 1K input tokens, $0.00125 per 1K output tokens

**For typical usage (~1000 messages/month):**
- **Old way:** ~$2-5/month (Anthropic) + ~$2/month (AWS infrastructure) = **$4-7/month**
- **New way:** ~$1/month (Bedrock) + ~$2/month (AWS infrastructure) = **$3/month**

**Bedrock is actually cheaper!** Plus simpler management.

---

## Testing

### Manual Test
```bash
# Get API endpoint
API_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

# Send test message
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Generate a simple Python Lambda function",
    "conversationId": "test-'$(date +%s)'"
  }'
```

### Automated Test
```bash
./validate-self.sh
```

### View Logs
```bash
sam logs -n CodingCopilotFunction \
  --stack-name prod-coding-copilot \
  --tail \
  --region us-east-2
```

---

## Troubleshooting

### "Access denied to Bedrock"
**Solution:** Enable model access (see Bedrock Setup above)

### "Model not found"
**Solution:** Make sure Claude 3 Haiku is enabled in your account

### "Throttling errors"
**Solution:** You may have hit Bedrock rate limits. Wait and retry.

### Cloud9 copilot won't open
**Solution:**
```bash
# Re-run integration
bash .cloud9/integrate.sh

# Or manually get frontend URL
aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text
```

### Deployment fails in CI/CD
**Solution:** Make sure GitHub secrets are set correctly

---

## Summary

### For the User Who Needs to Leave NOW:

```bash
# 1. Enable Bedrock (one-time, 30 seconds):
# https://console.aws.amazon.com/bedrock → Model access → Enable Claude 3 Haiku

# 2. Run this ONE command:
./setup-everything.sh

# 3. Walk away! ☕
# Everything deploys automatically
# GitHub Actions will auto-deploy future changes
# Cloud9 integration available if needed
```

### What You Get:

✅ **Zero manual steps** after initial Bedrock enablement  
✅ **No API keys to manage** - AWS handles it  
✅ **Auto-deploy on git push** - GitHub Actions  
✅ **IDE integration** - Copilot in Cloud9  
✅ **One-command deployment** - `./setup-everything.sh`  
✅ **Cost optimized** - Actually cheaper than before!  
✅ **Production ready** - Fully tested and validated  

---

## Next Steps

1. **Enable Bedrock:** https://console.aws.amazon.com/bedrock
2. **Deploy:** `./setup-everything.sh`
3. **Use it:** Open the frontend URL or `./copilot` in Cloud9
4. **Set up CI/CD:** Add AWS secrets to GitHub
5. **Develop:** Push to main → auto-deploys!

**You're done! The copilot is now fully automated and using AWS Bedrock.** 🎉
