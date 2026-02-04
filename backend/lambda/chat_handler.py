import json
import os
import boto3
import anthropic
from datetime import datetime, timedelta
from decimal import Decimal

# ============================================
# CONFIGURATION
# ============================================
CONVERSATIONS_TABLE = os.environ.get('CONVERSATIONS_TABLE')
ANTHROPIC_API_KEY_PARAM = os.environ.get('ANTHROPIC_API_KEY_PARAM', '/prod/anthropic-api-key')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
ssm = boto3.client('ssm', region_name=AWS_REGION)

# Cache for API key
_anthropic_client = None

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


def error_response(message, status_code=400):
    """Return standardized error response."""
    return create_response(status_code, {'error': message})


def success_response(data):
    """Return standardized success response."""
    return create_response(200, data)


# ============================================
# ANTHROPIC CLIENT
# ============================================
def get_anthropic_client():
    """Initialize and cache Anthropic client with API key from SSM."""
    global _anthropic_client
    
    if _anthropic_client is None:
        try:
            response = ssm.get_parameter(
                Name=ANTHROPIC_API_KEY_PARAM,
                WithDecryption=True
            )
            api_key = response['Parameter']['Value']
            _anthropic_client = anthropic.Anthropic(api_key=api_key)
        except Exception as e:
            print(f"Error retrieving API key from SSM: {str(e)}")
            raise Exception("Failed to initialize Anthropic client")
    
    return _anthropic_client


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
# ANTHROPIC API
# ============================================
def generate_response(user_message, conversation_history):
    """Generate a response using Anthropic API."""
    try:
        client = get_anthropic_client()
        
        # Build messages array with history
        messages = conversation_history.copy()
        messages.append({
            'role': 'user',
            'content': user_message
        })
        
        # Call Anthropic API
        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=messages
        )
        
        # Extract response text
        assistant_message = response.content[0].text
        
        print(f"Generated response with {len(assistant_message)} characters")
        return assistant_message
        
    except Exception as e:
        print(f"Error generating response: {str(e)}")
        raise Exception(f"Failed to generate response: {str(e)}")


# ============================================
# LAMBDA HANDLER
# ============================================
def lambda_handler(event, context):
    """Main Lambda handler for chat endpoint."""
    
    print(f"Received event: {json.dumps(event)}")
    
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
            return error_response("Missing request body", 400)
        
        body = json.loads(event['body'])
        user_message = body.get('message', '').strip()
        conversation_id = body.get('conversationId')
        
        if not user_message:
            return error_response("Message cannot be empty", 400)
        
        if not conversation_id:
            return error_response("conversationId is required", 400)
        
    except json.JSONDecodeError:
        return error_response("Invalid JSON in request body", 400)
    except Exception as e:
        return error_response(f"Error parsing request: {str(e)}", 400)
    
    # Process the message
    try:
        timestamp = datetime.utcnow().isoformat()
        
        # Get conversation history
        conversation_history = get_conversation_history(conversation_id)
        
        # Generate response
        assistant_message = generate_response(user_message, conversation_history)
        
        # Store user message
        store_message(conversation_id, 'user', user_message, timestamp)
        
        # Store assistant response
        store_message(conversation_id, 'assistant', assistant_message, timestamp)
        
        # Return response
        return success_response({
            'response': assistant_message,
            'conversationId': conversation_id,
            'timestamp': timestamp
        })
        
    except Exception as e:
        print(f"Error processing message: {str(e)}")
        return error_response(
            "I'm having trouble processing your request. Please try again in a moment.",
            500
        )
