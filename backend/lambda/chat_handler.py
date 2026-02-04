import json
import os
import boto3
from datetime import datetime, timedelta
from decimal import Decimal
import uuid

# ============================================
# CONFIGURATION
# ============================================
CONVERSATIONS_TABLE = os.environ.get('CONVERSATIONS_TABLE')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
USE_BEDROCK = os.environ.get('USE_BEDROCK', 'true').lower() == 'true'

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
bedrock = boto3.client('bedrock-runtime', region_name=AWS_REGION)

# Error type constants
ERROR_TYPE_INSUFFICIENT_CREDITS = 'insufficient_credits'
ERROR_TYPE_RATE_LIMIT = 'rate_limit'
ERROR_TYPE_INVALID_API_KEY = 'invalid_api_key'
ERROR_TYPE_ANTHROPIC_ERROR = 'anthropic_error'
ERROR_TYPE_SYSTEM_ERROR = 'system_error'

# Error message limits
MAX_ERROR_MESSAGE_LENGTH = 200

SYSTEM_PROMPT = """You are an expert AWS developer assistant. Help users with:
- Writing AWS Lambda functions (Python, Node.js)
- Creating SAM and CloudFormation templates
- AWS SDK code (boto3, AWS SDK for JavaScript)
- Deployment troubleshooting
- Cost optimization
- Best practices for AWS services

Provide complete, working code examples. Be concise but thorough."""


# ============================================
# UTILITY FUNCTIONS
# ============================================
def get_cors_headers():
    """Return CORS headers for API Gateway responses."""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Content-Type': 'application/json'
    }


def create_response(status_code, body):
    """Create a standardized response with CORS headers.
    
    Args:
        status_code: HTTP status code
        body: Response body (will be JSON serialized)
    
    Returns:
        dict: API Gateway response with CORS headers
    """
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(),
        'body': json.dumps(body)
    }


def error_response(message, status_code=400, error_type=None, can_retry=True, details=None):
    """Return standardized error response with additional metadata.
    
    Args:
        message: Human-readable error message
        status_code: HTTP status code
        error_type: Type of error (e.g., 'insufficient_credits', 'rate_limit')
        can_retry: Whether the request can be retried
        details: Additional error details (optional)
    
    Returns:
        dict: API Gateway response with error details
    """
    error_body = {
        'error': message,
        'canRetry': can_retry
    }
    
    if error_type:
        error_body['errorType'] = error_type
        
    if details:
        error_body['details'] = details
    
    return create_response(status_code, error_body)


def success_response(data):
    """Return standardized success response."""
    return create_response(200, data)


def parse_anthropic_error(error):
    """Parse Anthropic API errors and return structured error information.
    
    Args:
        error: Exception from Anthropic API
    
    Returns:
        tuple: (error_message, error_type, can_retry)
    """
    error_str = str(error)
    error_str_lower = error_str.lower()  # Convert once for performance
    error_message = error_str
    error_type = ERROR_TYPE_ANTHROPIC_ERROR
    can_retry = True
    
    # Check for insufficient credits
    if 'credit balance is too low' in error_str_lower or 'insufficient credits' in error_str_lower:
        error_type = ERROR_TYPE_INSUFFICIENT_CREDITS
        error_message = (
            "Your Anthropic API credit balance is too low. "
            "Please add credits at https://console.anthropic.com/settings/billing"
        )
        can_retry = False
        
    # Check for rate limit errors
    elif 'rate limit' in error_str_lower or 'too many requests' in error_str_lower:
        error_type = ERROR_TYPE_RATE_LIMIT
        error_message = (
            "Rate limit reached. Please wait a moment and try again. "
            "If this persists, check your Anthropic account limits."
        )
        can_retry = True
        
    # Check for invalid API key
    elif 'api key' in error_str_lower and ('invalid' in error_str_lower or 'unauthorized' in error_str_lower):
        error_type = ERROR_TYPE_INVALID_API_KEY
        error_message = (
            "API key is invalid or missing. Please check your Anthropic API key configuration. "
            "The key should be stored in AWS SSM Parameter Store at /prod/anthropic-api-key"
        )
        can_retry = False
        
    # Check for authentication errors
    elif 'authentication' in error_str_lower or 'unauthorized' in error_str_lower:
        error_type = ERROR_TYPE_INVALID_API_KEY
        error_message = (
            "Authentication failed. Please verify your Anthropic API key is valid and has not expired."
        )
        can_retry = False
        
    # Generic Anthropic error
    else:
        # Try to extract a more specific message if possible
        if hasattr(error, 'message'):
            error_message = f"Anthropic API error: {error.message}"
        else:
            error_message = f"An error occurred with the AI service: {error_str[:MAX_ERROR_MESSAGE_LENGTH]}"
        can_retry = True
    
    return error_message, error_type, can_retry


# ============================================
# BEDROCK CLIENT
# ============================================
def call_bedrock_claude(messages, system_prompt, request_id):
    """Call Claude via AWS Bedrock.
    
    Args:
        messages: List of conversation messages
        system_prompt: System prompt for Claude
        request_id: Request ID for logging
        
    Returns:
        str: Claude's response text
    """
    try:
        # Prepare the request body for Bedrock
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "system": system_prompt,
            "messages": messages
        })
        
        # Call Bedrock with Claude Haiku model
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-haiku-20240307-v1:0',
            body=body
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        
        # Extract text from response
        if 'content' in response_body and len(response_body['content']) > 0:
            return response_body['content'][0]['text']
        else:
            raise Exception("No content in Bedrock response")
            
    except Exception as e:
        print(f"REQUEST_ID={request_id} ERROR: Bedrock call failed: {str(e)}")
        raise


# ============================================
# DYNAMODB FUNCTIONS
# ============================================
def store_message(conversation_id, sender, message, timestamp):
    """Store a message in DynamoDB."""
    try:
        table = dynamodb.Table(CONVERSATIONS_TABLE)
        
        # Calculate TTL (30 days from now)
        ttl = int((datetime.now() + timedelta(days=30)).timestamp())
        
        item = {
            'conversationId': conversation_id,
            'timestamp': timestamp,
            'sender': sender,
            'message': message,
            'ttl': ttl
        }
        
        table.put_item(Item=item)
        print(f"Stored message for conversation {conversation_id}")
        
    except Exception as e:
        print(f"Error storing message: {str(e)}")
        # Don't fail the request if storage fails
        pass


def get_conversation_history(conversation_id, limit=10):
    """Retrieve conversation history from DynamoDB."""
    try:
        table = dynamodb.Table(CONVERSATIONS_TABLE)
        
        response = table.query(
            KeyConditionExpression='conversationId = :conv_id',
            ExpressionAttributeValues={
                ':conv_id': conversation_id
            },
            ScanIndexForward=True,  # Sort by timestamp ascending
            Limit=limit * 2  # Get more to account for user+assistant pairs
        )
        
        messages = []
        for item in response.get('Items', []):
            messages.append({
                'role': 'user' if item['sender'] == 'user' else 'assistant',
                'content': item['message']
            })
        
        print(f"Retrieved {len(messages)} messages for conversation {conversation_id}")
        return messages
        
    except Exception as e:
        print(f"Error retrieving conversation history: {str(e)}")
        return []


# ============================================
# AI API
# ============================================
def generate_response(user_message, conversation_history, request_id):
    """Generate a response using AWS Bedrock.
    
    Args:
        user_message: The user's message
        conversation_history: Previous messages in the conversation
        request_id: Unique ID for this request (for logging)
    
    Returns:
        str: The assistant's response
        
    Raises:
        Exception: On API errors (with parsed error details)
    """
    try:
        # Build messages array with history
        messages = conversation_history.copy()
        messages.append({
            'role': 'user',
            'content': user_message
        })
        
        print(f"REQUEST_ID={request_id} Calling AWS Bedrock with {len(messages)} messages")
        
        # Call Bedrock
        assistant_message = call_bedrock_claude(messages, SYSTEM_PROMPT, request_id)
        
        print(f"REQUEST_ID={request_id} Generated response with {len(assistant_message)} characters")
        return assistant_message
        
    except Exception as e:
        print(f"REQUEST_ID={request_id} ERROR_TYPE=BedrockError: {str(e)}")
        
        # Parse Bedrock errors
        error_str = str(e).lower()
        
        if 'throttling' in error_str or 'rate' in error_str:
            error_message = "Rate limit reached. Please wait a moment and try again."
            error_type = ERROR_TYPE_RATE_LIMIT
            can_retry = True
        elif 'access' in error_str or 'denied' in error_str or 'authorized' in error_str:
            error_message = "Access denied to AWS Bedrock. Please ensure the Lambda has proper IAM permissions."
            error_type = ERROR_TYPE_INVALID_API_KEY
            can_retry = False
        elif 'model' in error_str and 'not found' in error_str:
            error_message = "Claude model not available in Bedrock. Please enable Claude models in your AWS account."
            error_type = ERROR_TYPE_SYSTEM_ERROR
            can_retry = False
        else:
            error_message = f"AI service error: {str(e)[:200]}"
            error_type = ERROR_TYPE_ANTHROPIC_ERROR
            can_retry = True
        
        # Create error with metadata
        error = Exception(error_message)
        error.error_type = error_type
        error.can_retry = can_retry
        raise error


# ============================================
# LAMBDA HANDLER
# ============================================
def lambda_handler(event, context):
    """Main Lambda handler for chat endpoint."""
    
    # Generate request ID for tracing
    request_id = str(uuid.uuid4())
    
    print(f"REQUEST_ID={request_id} Received event: {json.dumps(event)}")
    
    # Handle CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': ''
        }
    
    # Parse request body
    try:
        if 'body' not in event:
            return error_response(
                "Missing request body",
                400,
                error_type=ERROR_TYPE_SYSTEM_ERROR,
                can_retry=False
            )
        
        body = json.loads(event['body'])
        user_message = body.get('message', '').strip()
        conversation_id = body.get('conversationId')
        
        if not user_message:
            return error_response(
                "Message cannot be empty",
                400,
                error_type=ERROR_TYPE_SYSTEM_ERROR,
                can_retry=False
            )
        
        if not conversation_id:
            return error_response(
                "conversationId is required",
                400,
                error_type=ERROR_TYPE_SYSTEM_ERROR,
                can_retry=False
            )
        
    except json.JSONDecodeError:
        return error_response(
            "Invalid JSON in request body",
            400,
            error_type=ERROR_TYPE_SYSTEM_ERROR,
            can_retry=False
        )
    except Exception as e:
        print(f"REQUEST_ID={request_id} ERROR: Request parsing failed: {str(e)}")
        return error_response(
            f"Error parsing request: {str(e)}",
            400,
            error_type=ERROR_TYPE_SYSTEM_ERROR,
            can_retry=False
        )
    
    # Process the message
    try:
        timestamp = datetime.utcnow().isoformat()
        
        print(f"REQUEST_ID={request_id} Processing message for conversation {conversation_id}")
        
        # Get conversation history
        conversation_history = get_conversation_history(conversation_id)
        
        # Generate response
        assistant_message = generate_response(user_message, conversation_history, request_id)
        
        # Store user message
        store_message(conversation_id, 'user', user_message, timestamp)
        
        # Store assistant response
        store_message(conversation_id, 'assistant', assistant_message, timestamp)
        
        # Return response
        print(f"REQUEST_ID={request_id} Successfully processed request")
        return success_response({
            'response': assistant_message,
            'conversationId': conversation_id,
            'timestamp': timestamp,
            'requestId': request_id
        })
        
    except Exception as e:
        print(f"REQUEST_ID={request_id} ERROR: Processing failed: {str(e)}")
        print(f"REQUEST_ID={request_id} ERROR_DETAILS: {type(e).__name__}")
        
        # Check if this is a parsed error with metadata
        error_type = getattr(e, 'error_type', ERROR_TYPE_SYSTEM_ERROR)
        can_retry = getattr(e, 'can_retry', True)
        error_message = str(e)
        
        # If it's a generic system error without specific typing
        if error_type == ERROR_TYPE_SYSTEM_ERROR and 'Anthropic' not in error_message:
            # Check if it's a configuration error (SSM, etc.)
            if 'API key' in error_message or 'SSM' in error_message or 'Parameter' in error_message:
                error_type = ERROR_TYPE_INVALID_API_KEY
                can_retry = False
            else:
                error_message = (
                    "I'm having trouble processing your request. "
                    "This might be a temporary issue. Please try again in a moment."
                )
                can_retry = True
        
        return error_response(
            error_message,
            500,
            error_type=error_type,
            can_retry=can_retry
        )
