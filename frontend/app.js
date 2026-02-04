// ============================================
// CONFIGURATION - UPDATE THIS AFTER DEPLOYMENT
// ============================================
// Replace this with your actual API Gateway endpoint after deployment
// Example: https://abc123def4.execute-api.us-east-1.amazonaws.com/prod/chat
// This will be automatically replaced during deployment by deploy.sh
const API_ENDPOINT = 'YOUR_API_ENDPOINT_HERE';

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
// API FUNCTIONS
// ============================================
async function sendMessage() {
    const userInput = document.getElementById('userInput');
    const message = userInput.value.trim();
    
    if (!message || isLoading) {
        return;
    }
    
    // Validate API endpoint is configured
    if (API_ENDPOINT.includes('YOUR_API_ENDPOINT_HERE')) {
        showError('API endpoint not configured. Please update the API_ENDPOINT in app.js with your actual API Gateway URL.');
        return;
    }
    
    // Add user message to UI
    addMessage('user', message);
    userInput.value = '';
    
    // Set loading state
    setLoading(true);
    
    try {
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
        showError(error.message || 'Failed to connect to the server. Please try again.');
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
