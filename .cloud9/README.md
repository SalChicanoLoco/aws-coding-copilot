# Cloud9 IDE Integration

This directory contains scripts to integrate the AWS Coding Copilot directly into your Cloud9 IDE.

## Files

- **setup.sh** - Complete environment setup script
  - Installs dependencies (SAM CLI, npm)
  - Configures AWS region
  - Clones/updates repository
  - Deploys the application
  - Integrates copilot into IDE

- **integrate.sh** - IDE integration script
  - Creates a local copilot interface
  - Sets up quick-access commands
  - Embeds frontend in Cloud9-friendly HTML

## Quick Start

### From a New Cloud9 Environment

1. Open your Cloud9 IDE
2. In the terminal, run:
   ```bash
   curl -sSL https://raw.githubusercontent.com/SalChicanoLoco/aws-coding-copilot/main/.cloud9/setup.sh | bash
   ```

### From an Existing Repository

If you already have the repository cloned:

```bash
bash .cloud9/setup.sh
```

## Using the Integrated Copilot

Once setup is complete, you can launch the copilot in several ways:

### Method 1: Quick Command
```bash
./copilot
```

### Method 2: Launch Script
```bash
bash .copilot/launch.sh
```

### Method 3: Cloud9 Preview
1. In Cloud9, go to **Preview** → **Preview File**
2. Navigate to `.copilot/index.html`
3. The copilot will open in a preview pane

### Method 4: External Browser
Open the Frontend URL directly in any browser (provided in the setup output)

## What Gets Created

```
your-workspace/
├── .copilot/
│   ├── index.html       # Integrated copilot interface
│   ├── launch.sh        # Launcher script
│   └── copilot          # Quick access command
└── copilot              # Root-level shortcut
```

## Features

- 🤖 **AI-Powered Assistance** - Get help with AWS services, Lambda functions, SAM templates
- 🔄 **Context Awareness** - Maintains conversation history
- 🎨 **Cloud9-Optimized UI** - Designed to work seamlessly in the IDE
- ⚡ **Quick Access** - Simple `./copilot` command to launch
- 🌐 **Multi-Access** - Use in IDE, browser, or both simultaneously

## Usage Tips

1. **Keep it open in a tab** - Open the copilot in Cloud9's preview pane and keep it alongside your code
2. **Ask specific questions** - "Generate a Lambda function that processes S3 events"
3. **Request templates** - "Create a SAM template for an API Gateway with DynamoDB"
4. **Debug help** - "Why is my CloudFormation stack failing with this error: ..."
5. **Best practices** - "What's the best way to handle API throttling in Lambda?"

## Troubleshooting

### Copilot won't open
- Ensure the application is deployed: `./deploy-safe.sh --yes`
- Check the frontend URL is accessible
- Run `bash .cloud9/integrate.sh` to re-integrate

### API errors
- Verify the Anthropic API key is set in SSM Parameter Store
- Check CloudWatch logs: `sam logs -n CodingCopilotFunction --tail`
- Ensure you have credits in your Anthropic account

### Updates
To get the latest version:
```bash
git pull
bash .cloud9/setup.sh
```

## Manual Integration

If automatic integration doesn't work, you can manually:

1. Get the Frontend URL:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name prod-coding-copilot \
     --region us-east-2 \
     --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
     --output text
   ```

2. Open it in Cloud9's preview browser or external browser

## Support

For issues or questions:
- Check the main [README.md](../README.md)
- Review [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Open an issue on GitHub

## Architecture

The integration works by:
1. Deploying the Lambda + API Gateway + S3 frontend
2. Creating a local HTML wrapper optimized for Cloud9
3. Embedding the S3-hosted frontend in an iframe
4. Providing convenient launch commands

This gives you the full copilot experience right in your development environment!
