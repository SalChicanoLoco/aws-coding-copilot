# AWS Coding Copilot - Validation Checklist Generator

## Purpose
This document defines the validation checks that the AWS Coding Copilot should generate when creating AWS Lambda functions, APIs, and infrastructure code.

## Issues We Encountered & Solutions

### 1. CORS Configuration Issues

**Problem:** Lambda functions not returning CORS headers in all response paths
**Impact:** Frontend can't communicate with backend, preflight requests fail

**What the Copilot Should Generate:**

```python
# ALWAYS include this pattern in Lambda functions
def get_cors_headers():
    """Return CORS headers for API Gateway responses."""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json'
    }

def create_response(status_code, body):
    """Create response with CORS headers."""
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(),
        'body': json.dumps(body)
    }

def lambda_handler(event, context):
    # ALWAYS handle OPTIONS first
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': ''
        }
    
    # Use create_response for ALL returns
    try:
        # Your logic here
        return create_response(200, {'result': 'success'})
    except Exception as e:
        return create_response(500, {'error': str(e)})
```

**Validation Checks:**
- ✅ All response paths include CORS headers
- ✅ OPTIONS method is handled
- ✅ Error responses include CORS headers
- ✅ API Gateway CORS config matches Lambda CORS

### 2. Frontend API Configuration

**Problem:** Inverted validation logic, hardcoded endpoints
**Impact:** Frontend shows errors when properly configured

**What the Copilot Should Generate:**

```javascript
// Configuration with demo mode support
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE';

// Auto-detect demo mode
const DEMO_MODE = !API_ENDPOINT.startsWith('https://');

// Proper validation
function validateConfig() {
    if (DEMO_MODE) {
        console.warn('Running in demo mode - no backend required');
        return false; // Not an error, just demo mode
    }
    
    if (!API_ENDPOINT || API_ENDPOINT === 'YOUR_API_ENDPOINT_HERE') {
        console.error('API endpoint not configured');
        return false;
    }
    
    return true;
}

// Usage in API calls
async function sendMessage(message) {
    if (DEMO_MODE) {
        // Return simulated response
        return simulateResponse(message);
    }
    
    // Make real API call
    const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message })
    });
    
    return response.json();
}
```

**Validation Checks:**
- ✅ Check for placeholder values correctly
- ✅ Support demo/offline mode
- ✅ Clear error messages
- ✅ Don't hardcode specific endpoints

### 3. SAM/CloudFormation Template

**Problem:** Missing CORS configuration, inconsistent settings
**Impact:** CORS not working even with Lambda code correct

**What the Copilot Should Generate:**

```yaml
Resources:
  # API Gateway with CORS
  MyApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowOrigin: "'*'"
        AllowMethods: "'POST, OPTIONS, GET'"
        AllowHeaders: "'Content-Type'"
        MaxAge: "'600'"
  
  # Lambda Function
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.lambda_handler
      Runtime: python3.12
      Events:
        # POST endpoint
        ApiPost:
          Type: Api
          Properties:
            RestApiId: !Ref MyApi
            Path: /resource
            Method: POST
        # OPTIONS for CORS preflight
        ApiOptions:
          Type: Api
          Properties:
            RestApiId: !Ref MyApi
            Path: /resource
            Method: OPTIONS
```

**Validation Checks:**
- ✅ API Gateway has CORS configuration
- ✅ OPTIONS method is defined for all endpoints
- ✅ CORS settings match between API Gateway and Lambda
- ✅ Headers are properly quoted in YAML

### 4. Deployment Scripts

**Problem:** Running from wrong directory, missing prerequisites
**Impact:** Deployment fails with confusing errors

**What the Copilot Should Generate:**

```bash
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validation functions
check_directory() {
    if [ ! -f "template.yaml" ] && [ ! -f "backend/infrastructure/template.yaml" ]; then
        echo -e "${RED}❌ Error: Must run from project root${NC}"
        echo "Current directory: $(pwd)"
        echo "Expected files: template.yaml or backend/infrastructure/template.yaml"
        exit 1
    fi
}

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ Error: AWS CLI not installed${NC}"
        exit 1
    fi
}

check_sam_cli() {
    if ! command -v sam &> /dev/null; then
        echo -e "${RED}❌ Error: SAM CLI not installed${NC}"
        exit 1
    fi
}

check_stack_exists() {
    if ! aws cloudformation describe-stacks --stack-name "$1" --region "$2" &> /dev/null; then
        echo -e "${YELLOW}⚠️  Stack doesn't exist yet - will create${NC}"
        return 1
    fi
    return 0
}

# Main deployment
main() {
    echo "🚀 Starting deployment..."
    
    # Run all checks
    check_directory
    check_aws_cli
    check_sam_cli
    
    # Build and deploy
    echo "Building..."
    sam build
    
    echo "Deploying..."
    sam deploy
    
    echo -e "${GREEN}✅ Deployment complete!${NC}"
}

main
```

**Validation Checks:**
- ✅ Running from correct directory
- ✅ Prerequisites installed (AWS CLI, SAM CLI)
- ✅ AWS credentials configured
- ✅ Stack exists before updating
- ✅ Clear error messages with solutions

### 5. Testing & Validation

**Problem:** No automated tests for CORS, deployment validation
**Impact:** Issues only discovered in production

**What the Copilot Should Generate:**

```python
# test_lambda.py
import pytest
import json

def test_options_handler(lambda_function):
    """Test OPTIONS request returns CORS headers."""
    event = {'httpMethod': 'OPTIONS'}
    response = lambda_function.lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    assert 'headers' in response
    assert response['headers']['Access-Control-Allow-Origin'] == '*'
    assert 'POST' in response['headers']['Access-Control-Allow-Methods']

def test_error_has_cors(lambda_function):
    """Test error responses include CORS headers."""
    event = {
        'httpMethod': 'POST',
        'body': 'invalid json'
    }
    response = lambda_function.lambda_handler(event, None)
    
    assert response['statusCode'] >= 400
    assert 'headers' in response
    assert 'Access-Control-Allow-Origin' in response['headers']

def test_success_has_cors(lambda_function, mock_dependencies):
    """Test success responses include CORS headers."""
    event = {
        'httpMethod': 'POST',
        'body': json.dumps({'test': 'data'})
    }
    response = lambda_function.lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    assert 'headers' in response
    assert 'Access-Control-Allow-Origin' in response['headers']
```

**Validation Checks:**
- ✅ Test OPTIONS handling
- ✅ Test CORS on success responses
- ✅ Test CORS on error responses
- ✅ Test all response paths
- ✅ Integration tests with real API Gateway

### 6. CI/CD Pipeline Checks

**What the Copilot Should Generate:**

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate SAM Template
        run: sam validate --lint
      
      - name: Check CORS Configuration
        run: |
          # Check Lambda has CORS headers
          grep -q "Access-Control-Allow-Origin" backend/lambda/*.py
          
          # Check API Gateway has CORS
          grep -q "Cors:" backend/infrastructure/template.yaml
      
      - name: Run Tests
        run: pytest backend/lambda/tests/
  
  deploy:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - name: SAM Build
        run: sam build
      
      - name: SAM Deploy
        run: sam deploy --no-confirm-changeset
      
      - name: Test Deployed Endpoint
        run: |
          # Test OPTIONS
          curl -X OPTIONS "$API_ENDPOINT" -i | grep "access-control-allow-origin"
          
          # Test POST
          curl -X POST "$API_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d '{"test": "data"}' \
            -i | grep "access-control-allow-origin"
```

## Checklist for Generated Code

When generating Lambda functions + API Gateway:

### Lambda Code
- [ ] `get_cors_headers()` function defined
- [ ] `create_response()` helper for standardized responses
- [ ] OPTIONS method handler at top of lambda_handler
- [ ] All `return` statements use `create_response()`
- [ ] Error handling includes CORS headers
- [ ] JSON serialization in single place

### API Gateway Config
- [ ] `Cors` section defined on API resource
- [ ] `AllowOrigin`, `AllowMethods`, `AllowHeaders` set
- [ ] OPTIONS method event defined for each endpoint
- [ ] CORS headers match Lambda implementation

### Frontend Code
- [ ] API_ENDPOINT as configurable constant
- [ ] Demo mode detection (`!API_ENDPOINT.startsWith('https://')`)
- [ ] Validation checks for placeholder, not real endpoint
- [ ] Clear error messages
- [ ] Fetch includes `Content-Type: application/json`

### Deployment
- [ ] Prerequisites validation
- [ ] Directory check
- [ ] Clear error messages
- [ ] Success confirmation
- [ ] Output important URLs/endpoints

### Testing
- [ ] Test OPTIONS handler
- [ ] Test success responses have CORS
- [ ] Test error responses have CORS
- [ ] Mock external dependencies
- [ ] Integration tests if applicable

## Summary

**Key Principle:** CORS must be in EVERY response, EVERY path, EVERY time.

The AWS Coding Copilot should automatically include these patterns when generating:
- Lambda functions with API Gateway
- Frontend code calling APIs
- SAM/CloudFormation templates
- Deployment scripts
- Test files

**Never generate code that:**
- Returns responses without CORS headers
- Has CORS only on success paths
- Forgets OPTIONS handling
- Hardcodes endpoints without validation
- Lacks proper error handling
