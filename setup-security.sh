#!/bin/bash
# Setup security tools for the AWS Coding Copilot repository
# Run this once to install git-secrets and pre-commit hooks

set -e

echo "========================================"
echo "  Security Tools Setup"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOOLS_INSTALLED=0
TOOLS_FAILED=0

# 1. Install git-secrets
echo "1. Installing git-secrets..."
if command -v git-secrets &> /dev/null; then
    echo -e "${GREEN}✓${NC} git-secrets already installed"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
else
    echo "   Installing git-secrets..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install git-secrets || {
                echo -e "${RED}✗${NC} Failed to install git-secrets"
                TOOLS_FAILED=$((TOOLS_FAILED + 1))
            }
        else
            echo -e "${YELLOW}⚠${NC} Homebrew not found. Install manually:"
            echo "   https://github.com/awslabs/git-secrets"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if [ ! -d "/tmp/git-secrets" ]; then
            git clone https://github.com/awslabs/git-secrets.git /tmp/git-secrets
        fi
        cd /tmp/git-secrets
        sudo make install || {
            echo -e "${RED}✗${NC} Failed to install git-secrets"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠${NC} Unknown OS. Install manually:"
        echo "   https://github.com/awslabs/git-secrets"
        TOOLS_FAILED=$((TOOLS_FAILED + 1))
    fi
    
    if command -v git-secrets &> /dev/null; then
        echo -e "${GREEN}✓${NC} git-secrets installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    fi
fi
echo ""

# 2. Configure git-secrets for this repo
echo "2. Configuring git-secrets..."
if command -v git-secrets &> /dev/null; then
    # Install hooks
    git secrets --install -f || {
        echo -e "${YELLOW}⚠${NC} git-secrets hooks already installed"
    }
    
    # Register AWS patterns
    git secrets --register-aws || true
    
    # Add Anthropic API key pattern
    git secrets --add 'sk-ant-api03-[A-Za-z0-9\-_]{95,}' || true
    
    # Add allowed patterns
    git secrets --add --allowed 'sk-ant-\.\.\.' || true
    git secrets --add --allowed 'YOUR_KEY_HERE' || true
    git secrets --add --allowed 'REPLACE_WITH' || true
    
    echo -e "${GREEN}✓${NC} git-secrets configured"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
else
    echo -e "${RED}✗${NC} git-secrets not available"
    TOOLS_FAILED=$((TOOLS_FAILED + 1))
fi
echo ""

# 3. Install pre-commit
echo "3. Installing pre-commit..."
if command -v pre-commit &> /dev/null; then
    echo -e "${GREEN}✓${NC} pre-commit already installed"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
else
    echo "   Installing pre-commit..."
    if command -v pip3 &> /dev/null; then
        pip3 install pre-commit || {
            echo -e "${RED}✗${NC} Failed to install pre-commit"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    elif command -v pip &> /dev/null; then
        pip install pre-commit || {
            echo -e "${RED}✗${NC} Failed to install pre-commit"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    else
        echo -e "${YELLOW}⚠${NC} pip not found. Install manually:"
        echo "   pip install pre-commit"
        TOOLS_FAILED=$((TOOLS_FAILED + 1))
    fi
    
    if command -v pre-commit &> /dev/null; then
        echo -e "${GREEN}✓${NC} pre-commit installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    fi
fi
echo ""

# 4. Install pre-commit hooks
echo "4. Installing pre-commit hooks..."
if command -v pre-commit &> /dev/null; then
    pre-commit install || {
        echo -e "${RED}✗${NC} Failed to install pre-commit hooks"
        TOOLS_FAILED=$((TOOLS_FAILED + 1))
    }
    
    if [ -f ".git/hooks/pre-commit" ]; then
        echo -e "${GREEN}✓${NC} pre-commit hooks installed"
        TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    fi
else
    echo -e "${RED}✗${NC} pre-commit not available"
    TOOLS_FAILED=$((TOOLS_FAILED + 1))
fi
echo ""

# 5. Test the setup
echo "5. Testing secret detection..."
if command -v git-secrets &> /dev/null; then
    # Create a temporary test file
    echo "test-key-sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" > /tmp/test-secret.txt
    
    if git secrets --scan /tmp/test-secret.txt 2>&1 | grep -q "prohibited"; then
        echo -e "${GREEN}✓${NC} Secret detection working!"
        rm /tmp/test-secret.txt
    else
        echo -e "${YELLOW}⚠${NC} Secret detection may not be working properly"
        rm /tmp/test-secret.txt
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot test - git-secrets not installed"
fi
echo ""

# Summary
echo "========================================"
echo "  Setup Summary"
echo "========================================"
echo -e "Tools installed: ${GREEN}$TOOLS_INSTALLED${NC}"
echo -e "Tools failed: ${RED}$TOOLS_FAILED${NC}"
echo ""

if [ $TOOLS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Security tools setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Try committing a file - hooks will automatically scan for secrets"
    echo "2. Read SECURITY.md for best practices"
    echo "3. Scan existing history: git secrets --scan-history"
    echo ""
else
    echo -e "${YELLOW}⚠️  Some tools failed to install${NC}"
    echo ""
    echo "Manual installation may be required:"
    echo "- git-secrets: https://github.com/awslabs/git-secrets"
    echo "- pre-commit: pip install pre-commit"
    echo ""
fi

echo "========================================"
echo ""
