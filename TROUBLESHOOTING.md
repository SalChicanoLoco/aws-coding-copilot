# Troubleshooting Guide

## SSL/Certificate Issues

### Problem: "SSL Certificate Error" or "Failed to fetch"

**Symptoms:**
- Frontend cannot connect to the API
- Browser shows certificate warnings
- Console shows ERR_CERT_* errors

**Common Causes & Solutions:**

#### 1. Self-Signed Certificate
**Cause:** API endpoint uses a self-signed SSL certificate
**Solution:** 
- Use AWS API Gateway (includes valid SSL certificates automatically)
- For custom domains, use AWS Certificate Manager (ACM)
- For development: Use **Demo Mode** (no real API calls)

#### 2. Certificate Domain Mismatch
**Cause:** SSL certificate doesn't match the API domain
**Solution:**
- Ensure your API Gateway custom domain matches your certificate
- Check ACM certificate includes the correct domain names

#### 3. Expired Certificate
**Cause:** SSL certificate has expired
**Solution:**
- Renew certificate in AWS Certificate Manager
- ACM certificates auto-renew if DNS validation is configured

#### 4. Mixed Content (HTTP/HTTPS)
**Cause:** Frontend served over HTTPS trying to call HTTP API
**Solution:**
- Ensure API endpoint uses HTTPS
- API Gateway always provides HTTPS endpoints

### Development Workarounds

#### Option 1: Demo Mode (Recommended)
The frontend includes a built-in demo mode that works without any backend:
- No API endpoint needed
- Simulated responses for testing UI
- Automatically enabled when `API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE'`

#### Option 2: Use AWS API Gateway
AWS API Gateway provides valid SSL certificates automatically:
```bash
./deploy.sh
```
This deploys the backend with a valid HTTPS endpoint.

#### Option 3: Local Development with CORS Proxy
For local testing with a real backend:
```bash
# Not recommended, but possible with a CORS proxy
# Better to use demo mode or deploy to AWS
```

## CORS Issues

### Problem: "CORS policy" errors

**Cause:** API doesn't allow requests from your frontend domain

**Solution:**
The backend SAM template includes CORS configuration. Ensure:
1. Backend is deployed with `./deploy.sh`
2. API Gateway CORS is enabled (included in template)
3. Frontend domain is allowed (wildcard `*` is set by default)

## Connection Issues

### Problem: "Failed to connect"

**Checklist:**
- [ ] Is the API endpoint configured correctly?
- [ ] Is the backend deployed? (`aws cloudformation describe-stacks --stack-name aws-coding-copilot`)
- [ ] Is the API endpoint accessible? (`curl -X POST [endpoint]`)
- [ ] Are you behind a corporate firewall blocking AWS endpoints?
- [ ] Is your AWS region correct? (default: us-east-1)

### Quick Test: Use Demo Mode
```javascript
// In frontend/app.js, ensure:
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE';
// This enables demo mode automatically
```

Refresh the frontend and it will work without any backend.

## API Gateway Issues

### Verifying API Gateway Deployment

```bash
# Check if stack exists
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1

# Get API endpoint
aws cloudformation describe-stacks \
  --stack-name aws-coding-copilot \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text

# Test API endpoint
curl -X POST [your-endpoint-here] \
  -H 'Content-Type: application/json' \
  -d '{"message":"test","conversationId":"test-123"}'
```

## Browser Console Debugging

### Checking for Errors
1. Open browser Developer Tools (F12)
2. Go to Console tab
3. Look for red error messages
4. Common errors and meanings:

```
ERR_CERT_AUTHORITY_INVALID
→ Self-signed certificate (use AWS API Gateway or demo mode)

ERR_CERT_COMMON_NAME_INVALID
→ Domain mismatch (check certificate domain)

Failed to fetch
→ Network/CORS/SSL issue (check backend deployment)

CORS policy
→ Backend not configured for CORS (ensure latest deployment)
```

## Getting Help

If issues persist:
1. Check browser console for specific error messages
2. Verify backend deployment status
3. Test API endpoint with curl
4. Use demo mode for frontend testing
5. Check AWS CloudWatch logs for backend errors

## Demo Mode

Demo mode allows you to test and explore the frontend without deploying any backend infrastructure:

**Features:**
- ✅ No AWS deployment needed
- ✅ No SSL/certificate issues
- ✅ Instant responses
- ✅ Test UI and functionality
- ✅ Simulated AWS coding assistance

**To Enable:**
Demo mode is automatically enabled when `API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE'`

**To Disable:**
Set API_ENDPOINT to your real API Gateway endpoint (happens automatically during `./deploy.sh`)
