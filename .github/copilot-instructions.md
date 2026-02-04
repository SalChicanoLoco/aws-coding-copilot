# GitHub Copilot Instructions for AWS Coding Copilot

## Project Overview

**AWS Coding Copilot** is a production-ready AI coding assistant that helps developers work with AWS services. It's a self-deploying, self-documenting application that demonstrates isomorphic development principles.

**Key Philosophy**: If a tool for building AWS apps can't deploy itself reliably, it can't be trusted to help others.

## Technology Stack

### Frontend
- **Static Website**: HTML, CSS, JavaScript (vanilla)
- **Hosting**: AWS S3 with static website hosting
- **Location**: `/frontend/` directory
  - `index.html` - Main UI
  - `app.js` - JavaScript logic
  - `style.css` - Styles

### Backend
- **Runtime**: AWS Lambda (Python 3.12)
- **Deployment**: Container-based using Docker
- **API**: AWS API Gateway (REST API)
- **Database**: DynamoDB (PAY_PER_REQUEST mode, 30-day TTL)
- **AI Provider**: Anthropic Claude API
- **Infrastructure as Code**: AWS SAM (Serverless Application Model)
- **Location**: `/backend/` directory
  - `lambda/chat_handler.py` - Lambda function
  - `lambda/Dockerfile` - Container image definition
  - `lambda/requirements.txt` - Python dependencies (boto3, anthropic)
  - `infrastructure/template.yaml` - SAM template
  - `infrastructure/samconfig.toml` - SAM configuration

### Infrastructure
- **Region**: us-east-2 (default)
- **Stack Name**: prod-coding-copilot
- **Services Used**:
  - AWS Lambda (512MB memory, container-based)
  - API Gateway (REST API with CORS)
  - DynamoDB (conversations table with TTL)
  - S3 (static website hosting)
  - SSM Parameter Store (encrypted API keys)
  - CloudFormation (via SAM)

## Project Structure

```
aws-coding-copilot/
├── .github/                    # GitHub configuration
│   └── copilot-instructions.md # This file
├── frontend/                   # Static website files
│   ├── index.html
│   ├── app.js
│   └── style.css
├── backend/
│   ├── lambda/                 # Lambda function code
│   │   ├── chat_handler.py    # Main handler
│   │   ├── requirements.txt   # Python dependencies
│   │   └── Dockerfile         # Container image
│   └── infrastructure/         # SAM templates
│       ├── template.yaml      # Infrastructure definition
│       ├── samconfig.toml     # SAM configuration
│       └── cleanup.sh         # Cleanup script
├── deploy-safe.sh             # Primary deployment script (use this!)
├── deploy.sh                  # Legacy deployment script
├── validate-self.sh           # Deployment validation
├── simulate-deploy.sh         # Deployment simulation
└── Documentation files (.md)  # Various guides
```

## Development Workflow

### Building & Testing

1. **Prerequisites Check**:
   - AWS CLI (v2.x+) configured with credentials
   - SAM CLI (v1.100.0+)
   - Docker Desktop running
   - Anthropic API key stored in SSM Parameter Store

2. **Build the Backend**:
   ```bash
   cd backend/infrastructure
   sam build
   ```
   - This builds the Lambda container image using Docker
   - Requires Docker to be running
   - Takes 2-3 minutes on first build

3. **Deploy**:
   ```bash
   ./deploy-safe.sh
   ```
   - **ALWAYS use `deploy-safe.sh`** (not `deploy.sh`)
   - Validates prerequisites automatically
   - Detects and fixes region mismatches
   - Cleans up orphaned resources
   - Configures frontend with API endpoint
   - Uploads frontend to S3

4. **Validate Deployment**:
   ```bash
   ./validate-self.sh
   ```
   - Checks stack status
   - Tests API endpoint
   - Verifies frontend accessibility

5. **View Logs**:
   ```bash
   sam logs -n CodingCopilotFunction --stack-name prod-coding-copilot --tail --region us-east-2
   ```

### Testing

- **No automated test suite**: This project doesn't have unit/integration tests
- **Testing approach**: Deploy and validate using `validate-self.sh`
- **Manual testing**: Open the frontend URL and interact with the chatbot

## Coding Conventions & Best Practices

### Python (Backend)

1. **Error Handling**:
   - Always wrap Lambda handler in try-except
   - Return proper HTTP status codes (200, 400, 500)
   - Include CORS headers in all responses

2. **Dependencies**:
   - Keep `requirements.txt` minimal (currently: boto3, anthropic)
   - Pin major versions: `package>=X.Y.0`

3. **Lambda Function Structure**:
   - Single handler function: `lambda_handler(event, context)`
   - Parse JSON body from API Gateway
   - Use boto3 for AWS service interactions
   - Store secrets in SSM Parameter Store, never in code

4. **DynamoDB**:
   - Use conversation_id as partition key
   - Include TTL (expires_at) for automatic cleanup
   - Use PAY_PER_REQUEST billing mode

### JavaScript (Frontend)

1. **Style**:
   - Vanilla JavaScript (no frameworks)
   - Use `const` and `let`, never `var`
   - Keep code simple and readable

2. **API Communication**:
   - Use `fetch()` for API calls
   - Handle errors gracefully with user feedback
   - Show loading states during API calls

### Infrastructure as Code (SAM)

1. **Template Structure**:
   - Use SAM (not raw CloudFormation) for Lambda/API
   - Define all resources in `template.yaml`
   - Use logical names that match purpose

2. **Best Practices**:
   - Always include CORS configuration
   - Use least-privilege IAM policies
   - Enable encryption for sensitive data (SSM)
   - Set appropriate timeouts (30s for Lambda)
   - Use container images for Lambda (better consistency)

3. **Configuration**:
   - Store deployment config in `samconfig.toml`
   - Use consistent stack name: `prod-coding-copilot`
   - Default region: `us-east-2`

## Common Tasks

### Adding a New Lambda Feature

1. Modify `backend/lambda/chat_handler.py`
2. Update `requirements.txt` if new dependencies needed
3. Run `sam build` from `backend/infrastructure/`
4. Deploy with `./deploy-safe.sh`
5. Test with `./validate-self.sh`

### Updating the Frontend

1. Modify files in `frontend/`
2. Deploy with `./deploy-safe.sh` (handles frontend sync)
3. Or manually sync: `aws s3 sync frontend/ s3://BUCKET/ --delete --region us-east-2`

### Changing AWS Region

1. Update `backend/infrastructure/samconfig.toml`
2. Update region in deploy scripts if hardcoded
3. Move SSM parameter to new region
4. Redeploy with `./deploy-safe.sh`

### Troubleshooting Failed Deployments

1. Check Docker is running: `docker info`
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Clean up stack: `cd backend/infrastructure && ./cleanup.sh`
4. Check for orphaned S3 buckets: `aws s3 ls | grep coding-copilot`
5. Redeploy: `./deploy-safe.sh`

## Important Constraints

### DO NOT:
- ❌ Remove or modify existing deployment scripts without testing
- ❌ Change the stack name (breaks existing deployments)
- ❌ Add heavy frameworks (keep frontend vanilla)
- ❌ Store API keys in code (use SSM Parameter Store)
- ❌ Use `deploy.sh` for new deployments (use `deploy-safe.sh`)
- ❌ Create provisioned DynamoDB capacity (use PAY_PER_REQUEST)
- ❌ Add VPC or NAT Gateway (increases cost unnecessarily)
- ❌ Remove Docker requirement (Lambda uses container images)

### DO:
- ✅ Use `deploy-safe.sh` for all deployments
- ✅ Test deployments with `validate-self.sh`
- ✅ Keep infrastructure minimal and cost-effective
- ✅ Include CORS headers in all Lambda responses
- ✅ Use container-based Lambda deployment
- ✅ Maintain 30-day TTL on DynamoDB items
- ✅ Follow existing code patterns and structure
- ✅ Update documentation when making significant changes

## Security

- **API Keys**: Stored as SecureString in SSM Parameter Store (`/prod/anthropic-api-key`)
- **CORS**: Configured on API Gateway, enforced in Lambda responses
- **IAM**: Least-privilege policies (Lambda can only access DynamoDB, SSM)
- **Encryption**: Data encrypted at rest (DynamoDB) and in transit (HTTPS)
- **TTL**: Automatic cleanup of old conversations (30 days)

## Cost Considerations

- **Target**: <$2/month for AWS infrastructure
- **Optimization**:
  - DynamoDB: PAY_PER_REQUEST (no idle costs)
  - Lambda: Container image with 512MB memory
  - S3: Static website hosting (very cheap)
  - No VPC, NAT Gateway, or CloudFront (avoid fixed costs)
  - 30-day TTL reduces storage costs

## Version Control

- **Main Branch**: Production-ready code
- **Commits**: Make small, focused commits
- **Messages**: Use descriptive commit messages
- **Before Committing**:
  - Test deployment with `validate-self.sh`
  - Ensure Docker build succeeds
  - Verify no secrets in code

## Getting Help

- **Documentation**: Check README.md and other .md files in root
- **Deployment Issues**: See DEPLOYMENT.md and TROUBLESHOOTING.md
- **Architecture**: See README.md (includes architecture diagram)
- **Validation**: Run `./validate-self.sh` to check deployment health

## Future Plans

- Render version for simpler deployment (see RENDER_MIGRATION_PLAN.md)
- Multi-platform support
- Enhanced self-testing capabilities

---

**Remember**: This project is self-deploying and self-documenting. Any changes should maintain these capabilities. When in doubt, deploy and validate!
