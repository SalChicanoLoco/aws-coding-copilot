#!/bin/bash
# Cloud9 IDE Integration for AWS Coding Copilot
# This script sets up the copilot to be accessible within Cloud9

set -e

echo "=========================================="
echo "  Cloud9 IDE Copilot Integration"
echo "=========================================="
echo ""

# Get the API endpoint and frontend URL
REGION="us-east-2"

echo "📡 Retrieving deployment endpoints..."
API_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ChatEndpoint`].OutputValue' \
  --output text 2>/dev/null || echo "")

FRONTEND_URL=$(aws cloudformation describe-stacks \
  --stack-name prod-coding-copilot \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
  --output text 2>/dev/null || echo "")

if [ -z "$API_URL" ] || [ -z "$FRONTEND_URL" ]; then
    echo "❌ Could not retrieve endpoints. Make sure the application is deployed."
    echo "Run: ./deploy-safe.sh --yes"
    exit 1
fi

echo "API Endpoint: $API_URL"
echo "Frontend URL: $FRONTEND_URL"
echo ""

# Create a local copilot HTML file that can be previewed in Cloud9
echo "🎨 Creating integrated copilot interface..."
cat > /tmp/copilot-cloud9.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Coding Copilot - Cloud9 Integration</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            padding: 15px 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .header h1 {
            font-size: 18px;
            color: #333;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .cloud9-badge {
            background: #FF9900;
            color: white;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: bold;
        }
        
        .iframe-container {
            flex: 1;
            padding: 0;
            overflow: hidden;
        }
        
        iframe {
            width: 100%;
            height: 100%;
            border: none;
            background: white;
        }
        
        .loading {
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100%;
            color: white;
            font-size: 18px;
        }
        
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 4px solid white;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin-right: 15px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .shortcut-hint {
            font-size: 12px;
            color: #666;
            background: #f0f0f0;
            padding: 4px 8px;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>
            <span>🤖</span> AWS Coding Copilot
            <span class="cloud9-badge">Cloud9 Integration</span>
        </h1>
        <div class="shortcut-hint">
            💡 Tip: Ask about AWS services, Lambda functions, SAM templates, and more!
        </div>
    </div>
    
    <div class="iframe-container">
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <span>Loading Copilot...</span>
        </div>
        <iframe id="copilot-frame" src="FRONTEND_URL_PLACEHOLDER" onload="document.getElementById('loading').style.display='none';" style="display: block;"></iframe>
    </div>
</body>
</html>
EOF

# Replace placeholder with actual URL
sed -i "s|FRONTEND_URL_PLACEHOLDER|$FRONTEND_URL|g" /tmp/copilot-cloud9.html

# Copy to Cloud9 workspace
WORKSPACE_DIR="${C9_PROJECT:-/home/ec2-user/environment}"
mkdir -p "$WORKSPACE_DIR/.copilot"
cp /tmp/copilot-cloud9.html "$WORKSPACE_DIR/.copilot/index.html"

echo "✅ Copilot interface created at: $WORKSPACE_DIR/.copilot/index.html"
echo ""

# Create a launcher script
cat > "$WORKSPACE_DIR/.copilot/launch.sh" << 'LAUNCHER'
#!/bin/bash
# Quick launcher for AWS Coding Copilot in Cloud9

echo "=========================================="
echo "  Launching AWS Coding Copilot"
echo "=========================================="
echo ""
echo "🌐 Opening copilot in Cloud9 preview..."
echo ""
echo "The copilot interface will open in the preview pane."
echo "You can also access it directly at:"
LAUNCHER

echo "echo \"   $FRONTEND_URL\"" >> "$WORKSPACE_DIR/.copilot/launch.sh"

cat >> "$WORKSPACE_DIR/.copilot/launch.sh" << 'LAUNCHER'
echo ""
echo "💡 Usage tips:"
echo "   - Ask: 'Generate a Python Lambda function'"
echo "   - Ask: 'Create a SAM template for DynamoDB'"
echo "   - Ask: 'Help me debug this CloudFormation error'"
echo ""

# Try to open in Cloud9 preview if available
if [ ! -z "$C9_PID" ]; then
    # Running in Cloud9
    xdg-open "$(dirname "$0")/index.html" 2>/dev/null || \
    sensible-browser "$(dirname "$0")/index.html" 2>/dev/null || \
    echo "Please manually open: $(dirname "$0")/index.html in the Cloud9 preview"
else
    # Not in Cloud9, open in default browser
    xdg-open "$(dirname "$0")/index.html" 2>/dev/null || \
    sensible-browser "$(dirname "$0")/index.html" 2>/dev/null || \
    echo "Please open $(dirname "$0")/index.html in your browser"
fi
LAUNCHER

chmod +x "$WORKSPACE_DIR/.copilot/launch.sh"

# Create a desktop shortcut/command
cat > "$WORKSPACE_DIR/copilot" << 'SHORTCUT'
#!/bin/bash
# Quick access command for AWS Coding Copilot
bash ~/.copilot/launch.sh
SHORTCUT

# Also create in .copilot directory
cp "$WORKSPACE_DIR/copilot" "$WORKSPACE_DIR/.copilot/copilot"
chmod +x "$WORKSPACE_DIR/copilot"
chmod +x "$WORKSPACE_DIR/.copilot/copilot"

echo "=========================================="
echo "✅ Integration Complete!"
echo "=========================================="
echo ""
echo "🚀 To launch the copilot, run:"
echo "   ./copilot"
echo ""
echo "Or:"
echo "   bash .copilot/launch.sh"
echo ""
echo "📁 Files created:"
echo "   - .copilot/index.html (integrated interface)"
echo "   - .copilot/launch.sh (launcher script)"
echo "   - copilot (quick access command)"
echo ""
echo "🌐 Direct access:"
echo "   $FRONTEND_URL"
echo ""
echo "💡 Pro tip: In Cloud9, you can also:"
echo "   1. Preview → Preview File → .copilot/index.html"
echo "   2. Keep it open in a tab while coding"
echo "   3. Ask the copilot questions as you develop!"
echo ""
