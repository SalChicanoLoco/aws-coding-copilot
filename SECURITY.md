# Security Policy

## 🔒 API Key Management Best Practices

### **NEVER commit API keys to git!**

This project uses AWS Systems Manager Parameter Store (SSM) for secure API key storage.

## ✅ Correct Way to Store API Keys

### 1. Store in AWS SSM Parameter Store
```bash
# Create or update the Anthropic API key
aws ssm put-parameter \
  --name /prod/anthropic-api-key \
  --value "YOUR_ACTUAL_KEY_HERE" \
  --type SecureString \
  --region us-east-2 \
  --overwrite
```

### 2. Verify it's stored securely
```bash
# This will show the key is stored (but not the value)
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Values=/prod/anthropic-api-key" \
  --region us-east-2

# To retrieve the value (only when needed)
aws ssm get-parameter \
  --name /prod/anthropic-api-key \
  --with-decryption \
  --region us-east-2 \
  --query 'Parameter.Value' \
  --output text
```

### 3. Lambda retrieves it at runtime
The Lambda function automatically retrieves the key from SSM:
- See `backend/lambda/chat_handler.py` line 177-188
- Uses IAM role permissions (no hardcoded credentials)
- Key is cached in Lambda for performance

## 🚫 What NOT to Do

### ❌ NEVER do this:
```python
# BAD - Hardcoded in code
api_key = "sk-ant-api03-xxxxx..."

# BAD - In environment variable files
# .env
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx...

# BAD - In configuration files
# config.json
{"api_key": "sk-ant-api03-xxxxx..."}

# BAD - In shell scripts
API_KEY="sk-ant-api03-xxxxx..."
```

## 🔐 Security Measures in Place

### 1. Git-secrets Protection
```bash
# Install git-secrets
brew install git-secrets  # macOS
# or
pip install git-secrets   # Python

# Install hooks in this repository
git secrets --install
git secrets --register-aws
git secrets --add 'sk-ant-api03-[A-Za-z0-9\-_]{95,}'

# Scan repository
git secrets --scan
```

### 2. Pre-commit Hooks
```bash
# Install pre-commit
pip install pre-commit

# Setup in repository
pre-commit install

# This will automatically:
# - Scan for secrets before each commit
# - Check for AWS credentials
# - Validate shell scripts
# - Detect private keys
```

### 3. .gitignore Protections
The following are automatically ignored:
- `.env` files
- `*.key`, `*.pem` files
- AWS credentials files
- Config backup files

## 🚨 If You Accidentally Commit a Secret

### Immediate Actions:

1. **Disable the compromised key IMMEDIATELY**
   ```bash
   # For Anthropic keys - delete from console
   # https://console.anthropic.com/settings/keys
   
   # For AWS keys
   aws iam delete-access-key --access-key-id AKIA...
   ```

2. **Rotate the key**
   ```bash
   # Create new Anthropic API key
   # Then update SSM
   aws ssm put-parameter \
     --name /prod/anthropic-api-key \
     --value "NEW_KEY_HERE" \
     --type SecureString \
     --region us-east-2 \
     --overwrite
   ```

3. **Remove from git history** (if needed)
   ```bash
   # Use BFG Repo Cleaner or git filter-branch
   # https://rtyley.github.io/bfg-repo-cleaner/
   
   # Download BFG
   wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
   
   # Remove secrets
   java -jar bfg-1.14.0.jar --replace-text passwords.txt
   
   # Force push (CAREFUL!)
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

4. **Notify your team**
   - Send security alert
   - Update documentation
   - Review access logs

## 📋 Security Checklist

Before committing code, ensure:

- [ ] No API keys in code
- [ ] No AWS credentials in files
- [ ] No passwords or secrets
- [ ] All sensitive data uses SSM Parameter Store
- [ ] Pre-commit hooks are installed
- [ ] Git-secrets is configured

## 🔍 Regular Security Audits

### Scan for secrets in codebase
```bash
# Using trufflehog
trufflehog filesystem . --only-verified

# Using detect-secrets
detect-secrets scan --all-files

# Using git-secrets
git secrets --scan-history
```

### Review IAM permissions
```bash
# Check Lambda execution role
aws iam get-role --role-name prod-coding-copilot-CodingCopilotFunctionRole

# List attached policies
aws iam list-attached-role-policies \
  --role-name prod-coding-copilot-CodingCopilotFunctionRole
```

## 📞 Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. Email the repository owner directly
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## 🔗 Additional Resources

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Git-secrets Documentation](https://github.com/awslabs/git-secrets)

## 🎯 Key Takeaways

1. **Always** use AWS SSM Parameter Store for secrets
2. **Never** commit secrets to git
3. **Install** pre-commit hooks and git-secrets
4. **Rotate** keys regularly
5. **Monitor** for unauthorized access
6. **Respond** quickly to security alerts

---

**Remember:** Security is everyone's responsibility. When in doubt, ask before committing!
