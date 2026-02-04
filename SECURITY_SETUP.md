# 🔒 Security Setup - Quick Start Guide

## ⚠️ YOU ARE HERE BECAUSE...

An API key was accidentally committed to this repository. The key has been disabled, but we need to prevent this from happening again.

## 🚨 Immediate Actions Taken

1. ✅ **Key Disabled** - The compromised Anthropic API key has been disabled
2. ✅ **Security Tools Added** - Pre-commit hooks, git-secrets, and scanning tools configured
3. ✅ **Documentation Created** - Comprehensive security best practices documented

## 🎯 What You Need to Do Now

### Step 1: Generate a New API Key

1. Go to [Anthropic Console](https://console.anthropic.com/settings/keys)
2. Create a new API key
3. Copy the key (you'll need it in Step 2)

### Step 2: Store the Key Securely in AWS SSM

```bash
# Store the new key in AWS SSM Parameter Store
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_NEW_KEY_HERE" \
  --type SecureString \
  --region us-east-2 \
  --overwrite

# Verify it's stored
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Values=/prod/anthropic-api-key" \
  --region us-east-2
```

### Step 3: Install Security Tools

```bash
# Run the setup script
./setup-security.sh

# This will install:
# - git-secrets (prevents committing secrets)
# - pre-commit hooks (automatic scanning)
```

### Step 4: Deploy with New Key

```bash
# Deploy the application (will use new key from SSM)
./deploy-safe.sh --yes
```

### Step 5: Test It Works

```bash
# Get your API endpoint
API_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region us-east-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text)

# Test the Lambda
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!", "conversationId": "test"}'

# Should return a response from Claude!
```

## ✅ Verify Security Tools Are Working

### Test 1: Try to commit a fake secret (should fail)
```bash
# This should be BLOCKED by git-secrets
echo "sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" > test.txt
git add test.txt
git commit -m "test"

# Expected result: ❌ Commit blocked with error message
# If blocked, delete the test file:
rm test.txt
git reset HEAD test.txt
```

### Test 2: Verify pre-commit hooks
```bash
# Check if hooks are installed
ls -la .git/hooks/

# Should see:
# - pre-commit (from pre-commit framework)
# - pre-commit.legacy (from git-secrets)
```

### Test 3: Scan repository history
```bash
# Scan for any remaining secrets
git secrets --scan-history

# Expected result: No secrets found ✅
```

## 📚 Files Added/Modified

### New Security Files
- `.gitattributes` - Git LFS and security tracking
- `.gitsecrets` - Git-secrets pattern configuration
- `.pre-commit-config.yaml` - Pre-commit hooks configuration
- `SECURITY.md` - Comprehensive security documentation
- `setup-security.sh` - Automated security tools installation
- `.github/workflows/security-scan.yml` - Automated security scanning

### Updated Files
- `.gitignore` - Added patterns for keys, credentials, secrets

## 🛡️ Protection Layers Now in Place

1. **Pre-commit Hooks** ⚡
   - Automatically scan every commit for secrets
   - Block commits containing API keys
   - Check for AWS credentials

2. **Git-secrets** 🔒
   - Pattern matching for known secret formats
   - AWS patterns pre-configured
   - Anthropic API key pattern added

3. **GitHub Actions** 🤖
   - Daily security scans (2 AM UTC)
   - TruffleHog for secret detection
   - Gitleaks for credential scanning
   - CodeQL for code security
   - Snyk for dependency vulnerabilities

4. **SSM Parameter Store** 🔐
   - All secrets stored in AWS
   - Encrypted at rest
   - IAM controlled access
   - Automatic retrieval by Lambda

5. **Enhanced .gitignore** 🚫
   - Blocks common secret file patterns
   - Prevents credential files
   - Ignores security scan results

## ❓ FAQ

### Q: What if I need to use a different API key temporarily?
**A:** Always update it in SSM, never in code:
```bash
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "TEMPORARY_KEY" \
  --type SecureString \
  --region us-east-2 \
  --overwrite
```

### Q: Can I commit `.env` files?
**A:** NO! `.env` files are blocked by `.gitignore`. Use SSM instead.

### Q: What if pre-commit hooks slow me down?
**A:** You can skip them temporarily with:
```bash
git commit --no-verify -m "message"
```
**BUT:** Only do this if you're 100% sure there are no secrets!

### Q: How do I rotate the API key?
**A:** Follow the key rotation procedure in `SECURITY.md`

### Q: What if I accidentally commit a secret anyway?
**A:** See "If You Accidentally Commit a Secret" in `SECURITY.md`

## 🎓 Best Practices Summary

### ✅ DO
- Store ALL secrets in AWS SSM Parameter Store
- Run `./setup-security.sh` after cloning the repo
- Test the security tools are working
- Review `SECURITY.md` for detailed guidance
- Keep API keys rotated regularly

### ❌ DON'T
- Commit API keys, passwords, or credentials
- Store secrets in environment variables in code
- Disable security hooks without good reason
- Share API keys in Slack, email, or documents
- Use personal API keys in shared deployments

## 📞 Need Help?

1. **Read the detailed guide**: `SECURITY.md`
2. **Check deployment docs**: `DEPLOYMENT.md`
3. **Report security issues**: Email repository owner (not GitHub issues!)

## 🎉 You're Protected!

Once you complete Steps 1-5 above, you'll have:
- ✅ New secure API key in SSM
- ✅ Automated secret scanning
- ✅ Pre-commit protection
- ✅ Working Lambda deployment
- ✅ Peace of mind 😌

**Remember:** Security is a habit, not a feature!

---

**Quick Reference:**
- 📖 Full security guide: `SECURITY.md`
- ⚙️ Setup script: `./setup-security.sh`
- 🚀 Deploy: `./deploy-safe.sh --yes`
- 🔍 Scan history: `git secrets --scan-history`
