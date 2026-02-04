// ============================================
// CONFIGURATION - UPDATE THIS AFTER DEPLOYMENT
// ============================================
// Replace this with your actual API Gateway endpoint after deployment
// Example: https://abc123def4.execute-api.us-east-1.amazonaws.com/prod/chat
// This will be automatically replaced during deployment by deploy.sh
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE';

// Demo mode - automatically enabled when API not configured
// Set this to true to force demo mode even with a configured API
const DEMO_MODE = API_ENDPOINT.includes('YOUR_API_ENDPOINT_HERE');

// Demo mode simulated delay (in milliseconds) to mimic real API response time
const DEMO_MODE_DELAY_MS = 800;

// ============================================
// NOTES ON SSL/CERTIFICATES
// ============================================
// If you encounter SSL certificate errors with your API Gateway:
// 1. Ensure your API Gateway has a valid SSL certificate
// 2. API Gateway endpoints should use AWS-managed certificates (valid by default)
// 3. For custom domains, ensure certificate is properly configured in ACM
// 4. For development/testing, use demo mode above (no API calls made)
//
// Common SSL errors:
// - ERR_CERT_AUTHORITY_INVALID: Self-signed certificate
// - ERR_CERT_COMMON_NAME_INVALID: Domain mismatch
// - ERR_CERT_DATE_INVALID: Expired certificate
//
// Note: Browsers enforce SSL validation and cannot bypass it via JavaScript

// ============================================
// GLOBAL STATE
// ============================================
let conversationId = generateConversationId();
let isLoading = false;

// ============================================
// UTILITY FUNCTIONS
// ============================================
function generateConversationId() {
    return 'conv-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
}

function formatTime(date) {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatMessage(text) {
    // Simple markdown-like formatting for code blocks
    let formatted = escapeHtml(text);
    
    // Handle code blocks (```language\ncode\n```)
    formatted = formatted.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
        return `<pre><code>${code.trim()}</code></pre>`;
    });
    
    // Handle inline code (`code`)
    formatted = formatted.replace(/`([^`]+)`/g, '<code>$1</code>');
    
    // Handle line breaks
    formatted = formatted.replace(/\n/g, '<br>');
    
    return formatted;
}

// ============================================
// UI FUNCTIONS
// ============================================
function addMessage(sender, content, timestamp = new Date()) {
    const conversation = document.getElementById('conversation');
    
    // Remove welcome message if it exists
    const welcomeMessage = conversation.querySelector('.welcome-message');
    if (welcomeMessage && sender === 'user') {
        welcomeMessage.remove();
    }
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}-message`;
    
    const messageHeader = document.createElement('div');
    messageHeader.className = 'message-header';
    
    const senderSpan = document.createElement('span');
    senderSpan.className = 'message-sender';
    senderSpan.textContent = sender === 'user' ? 'You' : 'AWS Copilot';
    
    const timeSpan = document.createElement('span');
    timeSpan.className = 'message-time';
    timeSpan.textContent = formatTime(timestamp);
    
    messageHeader.appendChild(senderSpan);
    messageHeader.appendChild(timeSpan);
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.innerHTML = formatMessage(content);
    
    messageDiv.appendChild(messageHeader);
    messageDiv.appendChild(contentDiv);
    
    conversation.appendChild(messageDiv);
    
    // Scroll to bottom
    conversation.scrollTop = conversation.scrollHeight;
}

function showError(message) {
    const conversation = document.getElementById('conversation');
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.innerHTML = `<strong>Error:</strong> ${escapeHtml(message)}`;
    conversation.appendChild(errorDiv);
    conversation.scrollTop = conversation.scrollHeight;
}

function setLoading(loading) {
    isLoading = loading;
    const button = document.getElementById('sendButton');
    const buttonText = document.getElementById('buttonText');
    const buttonSpinner = document.getElementById('buttonSpinner');
    const userInput = document.getElementById('userInput');
    
    button.disabled = loading;
    userInput.disabled = loading;
    
    if (loading) {
        buttonText.style.display = 'none';
        buttonSpinner.style.display = 'inline-block';
    } else {
        buttonText.style.display = 'inline';
        buttonSpinner.style.display = 'none';
    }
}

// ============================================
// DEMO MODE FUNCTIONS
// ============================================
function generateDemoResponse(message) {
    const responses = {
        lambda: `Here's a Python Lambda function example:

\`\`\`python
import json
import boto3

def lambda_handler(event, context):
    # Process S3 event
    s3 = boto3.client('s3')
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        print(f'Processing {key} from {bucket}')
        
        # Your processing logic here
        
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
\`\`\`

This Lambda function processes S3 events. Each record contains the bucket name and object key.

**Note:** You're in DEMO mode. Deploy the backend to use real AI responses.`,
        
        sam: `Here's a SAM template example:

\`\`\`yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Sample SAM Template

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.lambda_handler
      Runtime: python3.9
      CodeUri: ./src
      Events:
        ApiEvent:
          Type: Api
          Properties:
            Path: /hello
            Method: get
\`\`\`

**Note:** You're in DEMO mode. Deploy the backend to use real AI responses.`,
        
        default: `I'm the AWS Coding Copilot! I can help with:
- Writing Lambda functions (Python, Node.js)
- Creating SAM/CloudFormation templates
- AWS SDK examples
- Deployment troubleshooting
- Cost optimization

**⚠️ DEMO MODE:** You're seeing a simulated response. To get real AI-powered assistance:
1. Deploy the backend using \`./deploy.sh\`
2. The API endpoint will be automatically configured

Ask me about Lambda, S3, DynamoDB, or any AWS service!`
    };
    
    const lowerMessage = message.toLowerCase();
    if (lowerMessage.includes('lambda') || lowerMessage.includes('function')) {
        return responses.lambda;
    } else if (lowerMessage.includes('sam') || lowerMessage.includes('cloudformation') || lowerMessage.includes('template')) {
        return responses.sam;
    } else {
        return responses.default;
    }
}

// ============================================
// API FUNCTIONS
// ============================================
async function sendMessage() {
    const userInput = document.getElementById('userInput');
    const message = userInput.value.trim();
    
    if (!message || isLoading) {
        return;
    }
    
    // Add user message to UI
    addMessage('user', message);
    userInput.value = '';
    
    // Set loading state
    setLoading(true);
    
    try {
        // Check if in demo mode (API not configured)
        if (DEMO_MODE) {
            // Simulate API delay
            await new Promise(resolve => setTimeout(resolve, DEMO_MODE_DELAY_MS));
            
            // Generate demo response
            const demoResponse = generateDemoResponse(message);
            addMessage('assistant', demoResponse);
            return;
        }
        
        // Make real API call
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: message,
                conversationId: conversationId
            })
        });
        
        if (!response.ok) {
            let errorMessage = `Server returned ${response.status}: ${response.statusText}`;
            try {
                const errorData = await response.json();
                if (errorData.error) {
                    errorMessage = errorData.error;
                }
            } catch (e) {
                // Ignore JSON parse errors
            }
            throw new Error(errorMessage);
        }
        
        const data = await response.json();
        
        if (data.response) {
            addMessage('assistant', data.response);
        } else {
            throw new Error('No response from API');
        }
        
    } catch (error) {
        console.error('Error:', error);
        
        // Detect SSL/certificate errors
        let errorMessage = error.message || 'Failed to connect to the server. Please try again.';
        
        if (error.message && (
            error.message.includes('SSL') || 
            error.message.includes('certificate') || 
            error.message.includes('CERT')
        )) {
            errorMessage = `SSL Certificate Error: ${error.message}\n\n` +
                          `This usually means:\n` +
                          `1. The API endpoint uses a self-signed certificate\n` +
                          `2. The SSL certificate has expired\n` +
                          `3. The certificate domain doesn't match\n\n` +
                          `For development, you can use demo mode (already active if API not configured).`;
        } else if (error.message && error.message.includes('Failed to fetch')) {
            errorMessage = `Connection failed. Possible causes:\n` +
                          `1. API endpoint is not accessible\n` +
                          `2. CORS is not configured on the API\n` +
                          `3. SSL/certificate issues\n` +
                          `4. Network connectivity problems\n\n` +
                          `Try using demo mode for testing without a backend.`;
        }
        
        showError(errorMessage);
    } finally {
        setLoading(false);
        userInput.focus();
    }
}

// ============================================
// EVENT LISTENERS
// ============================================
document.addEventListener('DOMContentLoaded', () => {
    const userInput = document.getElementById('userInput');
    
    // Handle Enter key (Shift+Enter for new line)
    userInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });
    
    // Focus on input
    userInput.focus();
});
