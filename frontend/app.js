// ============================================
// CONFIGURATION - UPDATE THIS AFTER DEPLOYMENT
// ============================================
// Replace this with your actual API Gateway endpoint after deployment
// Example: https://abc123def4.execute-api.us-east-2.amazonaws.com/prod/chat
// This will be automatically replaced during deployment by deploy-safe.sh
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE';

// Demo mode - automatically enabled when API not configured
const DEMO_MODE = !API_ENDPOINT.startsWith('https://');

// Demo mode simulated delay (in milliseconds)
const DEMO_MODE_DELAY_MS = 1200;

// ============================================
// GLOBAL STATE
// ============================================
let conversationId = generateConversationId();
let isLoading = false;
let messageHistory = [];

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
    let formatted = escapeHtml(text);
    
    // Handle code blocks (```language\ncode\n```) FIRST to avoid formatting inside code
    const codeBlocks = [];
    formatted = formatted.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
        const langLabel = lang ? `<span class="code-language-label">${lang}</span>` : '';
        const placeholder = `___CODEBLOCK_${codeBlocks.length}___`;
        codeBlocks.push(`<pre><code>${langLabel}\n${code.trim()}</code></pre>`);
        return placeholder;
    });
    
    // Handle inline code (`code`) BEFORE other formatting
    const inlineCode = [];
    formatted = formatted.replace(/`([^`]+)`/g, (match, code) => {
        const placeholder = `___INLINECODE_${inlineCode.length}___`;
        inlineCode.push(`<code>${code}</code>`);
        return placeholder;
    });
    
    // Now handle bold and italic (they won't affect code anymore)
    // Handle bold (**text** or __text__)
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    formatted = formatted.replace(/__([^_]+)__/g, '<strong>$1</strong>');
    
    // Handle italic (*text* - but not mid-word underscores)
    formatted = formatted.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    
    // Handle line breaks
    formatted = formatted.replace(/\n/g, '<br>');
    
    // Restore inline code
    inlineCode.forEach((code, i) => {
        formatted = formatted.replace(`___INLINECODE_${i}___`, code);
    });
    
    // Restore code blocks
    codeBlocks.forEach((block, i) => {
        formatted = formatted.replace(`___CODEBLOCK_${i}___`, block);
    });
    
    return formatted;
}

function scrollToBottom() {
    const conversation = document.getElementById('conversation');
    conversation.scrollTop = conversation.scrollHeight;
}

// Auto-resize textarea
function autoResizeTextarea(textarea) {
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px';
}

// ============================================
// UI FUNCTIONS
// ============================================
function addMessage(sender, content, timestamp = new Date()) {
    const conversation = document.getElementById('conversation');
    
    // Remove welcome message on first user message
    const welcomeMessage = conversation.querySelector('.welcome-message');
    if (welcomeMessage && sender === 'user') {
        welcomeMessage.style.animation = 'fadeOut 0.3s ease-out';
        setTimeout(() => welcomeMessage.remove(), 300);
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
    
    // Store in history
    messageHistory.push({ sender, content, timestamp });
    
    // Scroll to bottom with animation
    setTimeout(scrollToBottom, 100);
}

function showTypingIndicator() {
    const conversation = document.getElementById('conversation');
    const indicator = document.createElement('div');
    indicator.id = 'typing-indicator';
    indicator.className = 'typing-indicator';
    indicator.innerHTML = '<span></span><span></span><span></span>';
    conversation.appendChild(indicator);
    scrollToBottom();
}

function hideTypingIndicator() {
    const indicator = document.getElementById('typing-indicator');
    if (indicator) {
        indicator.remove();
    }
}

function showError(message, errorType, canRetry) {
    const conversation = document.getElementById('conversation');
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    
    let errorIcon = '⚠️';
    let errorTitle = 'Error';
    let additionalInfo = '';
    
    // Customize based on error type
    if (errorType === 'insufficient_credits') {
        errorIcon = '💳';
        errorTitle = 'Anthropic API Credits Depleted';
        additionalInfo = `
            <div class="error-details">
                <p><strong>What to do:</strong></p>
                <ol>
                    <li>Add credits at: <a href="https://console.anthropic.com/settings/billing" target="_blank">Anthropic Billing</a></li>
                    <li>Refresh this page</li>
                    <li>Try your request again</li>
                </ol>
            </div>
        `;
    } else if (errorType === 'rate_limit') {
        errorIcon = '⏱️';
        errorTitle = 'Rate Limit Reached';
        additionalInfo = `
            <div class="error-details">
                <p><strong>What to do:</strong></p>
                <ul>
                    <li>Wait 30-60 seconds and try again</li>
                    <li>If this persists, check your <a href="https://console.anthropic.com/settings/limits" target="_blank">API limits</a></li>
                </ul>
                ${canRetry ? '<p class="retry-hint">✓ You can retry this request</p>' : ''}
            </div>
        `;
    } else if (errorType === 'invalid_api_key') {
        errorIcon = '🔑';
        errorTitle = 'API Configuration Error';
        additionalInfo = `
            <div class="error-details">
                <p><strong>Administrator action required:</strong></p>
                <ul>
                    <li>Check the Anthropic API key in AWS SSM Parameter Store</li>
                    <li>Ensure the key is valid and not expired</li>
                    <li>Redeploy the application after fixing</li>
                </ul>
            </div>
        `;
    } else if (errorType === 'anthropic_error') {
        errorIcon = '🤖';
        errorTitle = 'AI Service Error';
        additionalInfo = canRetry ? '<p class="retry-hint">✓ Please try again</p>' : '';
    }
    
    errorDiv.innerHTML = `
        <div class="error-header">
            <span class="error-icon">${errorIcon}</span>
            <strong>${errorTitle}</strong>
        </div>
        <div class="error-content">
            <p>${escapeHtml(message)}</p>
            ${additionalInfo}
        </div>
    `;
    
    conversation.appendChild(errorDiv);
    scrollToBottom();
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
        showTypingIndicator();
    } else {
        buttonText.style.display = 'flex';
        buttonSpinner.style.display = 'none';
        hideTypingIndicator();
    }
}

// ============================================
// DEMO MODE FUNCTIONS
// ============================================
function generateDemoResponse(message) {
    const responses = {
        lambda: `Here's a Python Lambda function that processes S3 events:

\`\`\`python
import json
import boto3

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """Process S3 event triggers"""
    
    for record in event['Records']:
        # Extract S3 bucket and object info
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        event_name = record['eventName']
        
        print(f'Processing {event_name} for {key} in {bucket}')
        
        # Example: Get object metadata
        try:
            response = s3_client.head_object(Bucket=bucket, Key=key)
            size = response['ContentLength']
            content_type = response.get('ContentType', 'unknown')
            
            print(f'Object size: {size} bytes, Type: {content_type}')
            
            # Add your processing logic here
            # For example: resize images, validate files, trigger workflows
            
        except Exception as e:
            print(f'Error processing {key}: {str(e)}')
            raise
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Processing complete',
            'processed': len(event['Records'])
        })
    }
\`\`\`

**Key Features:**
- Processes multiple S3 events in batch
- Extracts bucket name and object key from each record
- Includes error handling and logging
- Returns proper API Gateway response format

**Note:** You're in **DEMO mode**. Deploy the backend for real AI-powered responses!`,
        
        sam: `Here's a complete SAM template for a serverless API:

\`\`\`yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Serverless API with DynamoDB

Globals:
  Function:
    Timeout: 30
    Runtime: python3.12
    MemorySize: 512
    Environment:
      Variables:
        TABLE_NAME: !Ref DataTable

Resources:
  # API Gateway
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.lambda_handler
      CodeUri: ./src
      Events:
        GetApi:
          Type: Api
          Properties:
            Path: /items
            Method: get
        PostApi:
          Type: Api
          Properties:
            Path: /items
            Method: post
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref DataTable

  # DynamoDB Table
  DataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub 'https://\${ServerlessRestApi}.execute-api.\${AWS::Region}.amazonaws.com/Prod/'
\`\`\`

**Note:** You're in **DEMO mode**. Deploy the backend for real AI assistance!`,
        
        default: `I'm your **AWS Coding Copilot**! 🚀

I can help you with:
- **Lambda Functions** - Python, Node.js, and more
- **Infrastructure as Code** - SAM, CloudFormation, CDK
- **AWS SDK** - boto3, AWS SDK for JavaScript
- **Deployment** - Troubleshooting and best practices
- **Cost Optimization** - Reduce your AWS bill
- **Security** - IAM policies and best practices

**⚠️ DEMO MODE ACTIVE**

You're seeing simulated responses. To get real AI-powered assistance:
1. Run \`./deploy-safe.sh\` to deploy the backend
2. The API endpoint will be automatically configured
3. Start getting real AI help with your AWS development!

Ask me anything about AWS services, code examples, or deployment strategies!`
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
    userInput.style.height = 'auto';
    
    // Set loading state
    setLoading(true);
    
    try {
        // Check if in demo mode
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
            let errorType = null;
            let canRetry = true;
            
            try {
                const errorData = await response.json();
                if (errorData.error) {
                    errorMessage = errorData.error;
                }
                if (errorData.errorType) {
                    errorType = errorData.errorType;
                }
                if (errorData.canRetry !== undefined) {
                    canRetry = errorData.canRetry;
                }
            } catch (e) {
                // Ignore JSON parse errors
            }
            
            const error = new Error(errorMessage);
            error.errorType = errorType;
            error.canRetry = canRetry;
            throw error;
        }
        
        const data = await response.json();
        
        if (data.response) {
            addMessage('assistant', data.response);
        } else {
            throw new Error('No response from API');
        }
        
    } catch (error) {
        console.error('Error:', error);
        
        let errorMessage = error.message || 'Failed to connect to the server. Please try again.';
        let errorType = error.errorType || null;
        let canRetry = error.canRetry !== undefined ? error.canRetry : true;
        
        // Enhanced error messages for network errors
        if (error.message && error.message.includes('Failed to fetch')) {
            errorType = 'network_error';
            errorMessage = `**Connection Failed**

Possible causes:
• API endpoint is not accessible
• CORS is not configured properly
• Network connectivity issues
• SSL/certificate problems

Try using demo mode for testing without a backend.`;
        } else if (error.message && (error.message.includes('SSL') || error.message.includes('certificate'))) {
            errorType = 'ssl_error';
            errorMessage = `**SSL Certificate Error**

${error.message}

This usually means:
• Self-signed certificate in use
• SSL certificate has expired
• Certificate domain doesn't match

For development, you can use demo mode.`;
        }
        
        showError(errorMessage, errorType, canRetry);
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
    
    // Auto-resize textarea on input
    userInput.addEventListener('input', () => {
        autoResizeTextarea(userInput);
    });
    
    // Handle Ctrl+Enter to send (Enter for new line)
    userInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            sendMessage();
        }
    });
    
    // Focus on input
    userInput.focus();
    
    // Display demo mode notice if applicable
    if (DEMO_MODE) {
        console.log('%c🎮 Demo Mode Active', 'color: #FF9900; font-size: 16px; font-weight: bold;');
        console.log('%cYou\'re seeing simulated responses. Deploy the backend for real AI assistance.', 'color: #999;');
    }
});
