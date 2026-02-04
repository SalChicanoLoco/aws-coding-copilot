# Quick Reference - AWS Coding Copilot Automation

## 🚀 One-Line Deploys

```bash
# Complete setup (everything)
./setup-everything.sh

# Deploy without prompts
./deploy-safe.sh --yes

# Quick deploy
./quick-deploy.sh --yes

# Cloud9 setup
bash .cloud9/setup.sh
```

## 🤖 Launch Copilot in IDE

```bash
# From Cloud9 or any environment
./copilot

# Or
bash .copilot/launch.sh
```

## 🔑 AWS Bedrock Setup (First Time Only)

1. Visit: https://console.aws.amazon.com/bedrock
2. Click "Model access" → "Manage model access"
3. Enable "Claude 3 Haiku"
4. Done! (No API keys needed)

## 🧪 Testing

```bash
# Validate deployment
./validate-self.sh

# View logs
sam logs -n CodingCopilotFunction --tail --region us-east-2

# Test API
curl -X POST $(aws cloudformation describe-stacks --stack-name prod-coding-copilot --region us-east-2 --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' --output text) \
  -H "Content-Type: application/json" \
  -d '{"message": "test", "conversationId": "test"}'
```

## 📁 New Files Created

```
.cloud9/
├── setup.sh          # Auto-setup for Cloud9
├── integrate.sh      # IDE integration script
└── README.md         # Cloud9 documentation

.github/workflows/
└── auto-deploy.yml   # Auto-deploy on push to main

cloudformation/
└── cloud9-environment.yaml  # Cloud9 CloudFormation template

setup-everything.sh   # Master setup script
AUTOMATION_GUIDE.md  # This guide!
```

## 🔄 CI/CD Setup

Add these secrets to GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Then push to main → auto-deploys!

## 💡 Key Changes

| Old | New |
|-----|-----|
| Anthropic API + API keys | AWS Bedrock (no keys!) |
| Manual prompts | `--yes` flag everywhere |
| External API calls | Native AWS integration |
| Separate billing | Unified AWS bill |
| ~$5/month | ~$3/month |

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| "Access denied to Bedrock" | Enable model access in Bedrock console |
| "Model not found" | Request access to Claude 3 Haiku |
| Copilot won't open | Run `bash .cloud9/integrate.sh` |
| Deployment fails | Check Docker is running |

## 📞 Support

- [AUTOMATION_GUIDE.md](AUTOMATION_GUIDE.md) - Full documentation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting
- [README.md](README.md) - Architecture and overview
