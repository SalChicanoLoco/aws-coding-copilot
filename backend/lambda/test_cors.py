#!/usr/bin/env python3
"""
Simple test to verify CORS headers are present in all Lambda responses.
This test doesn't require AWS credentials or external dependencies.
"""
import json
import sys
import os
from unittest.mock import MagicMock, Mock

# Set environment variables
os.environ['CONVERSATIONS_TABLE'] = 'test-table'
os.environ['AWS_REGION'] = 'us-east-1'

# Mock AWS services
mock_dynamodb = MagicMock()
mock_ssm = MagicMock()
mock_table = MagicMock()
mock_table.put_item = MagicMock()
mock_table.query = MagicMock(return_value={'Items': []})
mock_dynamodb.Table = MagicMock(return_value=mock_table)
mock_ssm.get_parameter = MagicMock(return_value={'Parameter': {'Value': 'test-key'}})

# Mock boto3 module
sys.modules['boto3'] = MagicMock()
sys.modules['boto3'].resource = MagicMock(return_value=mock_dynamodb)
sys.modules['boto3'].client = MagicMock(return_value=mock_ssm)

# Mock anthropic module
mock_anthropic_instance = MagicMock()
mock_anthropic_class = MagicMock(return_value=mock_anthropic_instance)
sys.modules['anthropic'] = MagicMock()
sys.modules['anthropic'].Anthropic = mock_anthropic_class

# Now import chat_handler
import chat_handler

def test_cors_headers():
    """Test that all responses include CORS headers."""
    required_headers = [
        'Access-Control-Allow-Origin',
        'Access-Control-Allow-Methods', 
        'Access-Control-Allow-Headers'
    ]
    
    print("Testing CORS headers implementation...")
    print("-" * 50)
    
    # Test 1: OPTIONS request
    print("\n1. Testing OPTIONS preflight request...")
    event = {'httpMethod': 'OPTIONS'}
    response = chat_handler.lambda_handler(event, None)
    
    assert response['statusCode'] == 200, f"Expected 200, got {response['statusCode']}"
    assert 'headers' in response, "Response missing 'headers' field"
    
    for header in required_headers:
        assert header in response['headers'], f"Missing header: {header}"
        print(f"   ✓ {header}: {response['headers'][header]}")
    
    print("   ✓ OPTIONS request returns proper CORS headers")
    
    # Test 2: Missing body error
    print("\n2. Testing error response (missing body)...")
    event = {'httpMethod': 'POST'}
    response = chat_handler.lambda_handler(event, None)
    
    assert response['statusCode'] == 400, f"Expected 400, got {response['statusCode']}"
    assert 'headers' in response, "Response missing 'headers' field"
    
    for header in required_headers:
        assert header in response['headers'], f"Missing header: {header}"
    
    print("   ✓ Error response includes CORS headers")
    
    # Test 3: Invalid JSON error
    print("\n3. Testing error response (invalid JSON)...")
    event = {
        'httpMethod': 'POST',
        'body': 'invalid json {'
    }
    response = chat_handler.lambda_handler(event, None)
    
    assert response['statusCode'] == 400, f"Expected 400, got {response['statusCode']}"
    assert 'headers' in response, "Response missing 'headers' field"
    
    for header in required_headers:
        assert header in response['headers'], f"Missing header: {header}"
    
    print("   ✓ Invalid JSON error includes CORS headers")
    
    # Test 4: Missing message field
    print("\n4. Testing error response (missing message)...")
    event = {
        'httpMethod': 'POST',
        'body': json.dumps({'conversationId': 'test-123'})
    }
    response = chat_handler.lambda_handler(event, None)
    
    assert response['statusCode'] == 400, f"Expected 400, got {response['statusCode']}"
    assert 'headers' in response, "Response missing 'headers' field"
    
    for header in required_headers:
        assert header in response['headers'], f"Missing header: {header}"
    
    print("   ✓ Missing field error includes CORS headers")
    
    # Test 5: Verify create_response helper exists
    print("\n5. Testing create_response helper function...")
    assert hasattr(chat_handler, 'create_response'), "create_response function not found"
    
    test_response = chat_handler.create_response(200, {'test': 'data'})
    assert 'headers' in test_response, "create_response missing headers"
    
    for header in required_headers:
        assert header in test_response['headers'], f"Missing header in create_response: {header}"
    
    print("   ✓ create_response helper properly adds CORS headers")
    
    # Test 6: Verify CORS header values
    print("\n6. Verifying CORS header values...")
    headers = chat_handler.get_cors_headers()
    
    assert headers['Access-Control-Allow-Origin'] == '*', "Origin should be '*'"
    print(f"   ✓ Access-Control-Allow-Origin: {headers['Access-Control-Allow-Origin']}")
    
    assert 'POST' in headers['Access-Control-Allow-Methods'], "Methods should include POST"
    assert 'OPTIONS' in headers['Access-Control-Allow-Methods'], "Methods should include OPTIONS"
    print(f"   ✓ Access-Control-Allow-Methods: {headers['Access-Control-Allow-Methods']}")
    
    assert 'Content-Type' in headers['Access-Control-Allow-Headers'], "Headers should include Content-Type"
    print(f"   ✓ Access-Control-Allow-Headers: {headers['Access-Control-Allow-Headers']}")
    
    print("\n" + "=" * 50)
    print("✅ All CORS tests passed!")
    print("=" * 50)

if __name__ == '__main__':
    try:
        test_cors_headers()
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
