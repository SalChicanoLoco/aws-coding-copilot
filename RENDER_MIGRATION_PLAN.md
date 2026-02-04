# Migrating to Render - Implementation Plan

## Why Render?

### Problems with AWS Version
1. Complex deployment (SAM, CloudFormation)
2. Region configuration issues
3. Multiple AWS services to manage
4. Steep learning curve
5. AWS account required

### Benefits of Render
1. Git-push deployment
2. Simple environment variables
3. Single service (Web Service)
4. No cloud provider account needed
5. Predictable pricing ($7/month for starter)

## Architecture Changes

### AWS Version
```
S3/CloudFront → API Gateway → Lambda → DynamoDB
```

### Render Version
```
Render Web Service (Python FastAPI) → PostgreSQL
```

## Implementation Steps

### 1. Backend Changes

**Current**: Lambda function (`chat_handler.py`)
**New**: FastAPI application

```python
# render_backend/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from anthropic import Anthropic
import os
from sqlalchemy import create_engine
from datetime import datetime

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Anthropic client
anthropic_client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

# Database
engine = create_engine(os.environ["DATABASE_URL"])

@app.post("/chat")
async def chat(request: ChatRequest):
    # Same logic as Lambda handler
    pass

@app.get("/health")
async def health():
    return {"status": "healthy"}
```

### 2. Database Migration

**From**: DynamoDB
**To**: PostgreSQL (included with Render)

```sql
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    sender VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_conversation (conversation_id, timestamp)
);
```

### 3. Frontend Changes

**Minimal changes needed:**
- Update `API_ENDPOINT` to Render URL
- Same HTML/CSS/JS files
- Deploy as static site on Render

### 4. Deployment Configuration

**File**: `render.yaml`
```yaml
services:
  # Backend API
  - type: web
    name: aws-copilot-api
    env: python
    plan: starter
    buildCommand: "pip install -r requirements.txt"
    startCommand: "uvicorn main:app --host 0.0.0.0 --port $PORT"
    envVars:
      - key: ANTHROPIC_API_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: aws-copilot-db
          property: connectionString
    
  # Frontend
  - type: static
    name: aws-copilot-frontend
    staticPublishPath: ./frontend
    buildCommand: "echo 'No build needed'"
    envVars:
      - key: API_URL
        fromService:
          type: web
          name: aws-copilot-api
          envVarKey: RENDER_EXTERNAL_URL

databases:
  - name: aws-copilot-db
    plan: starter
    databaseName: conversations
```

### 5. File Structure

```
render-version/
├── backend/
│   ├── main.py              # FastAPI app
│   ├── database.py          # PostgreSQL connection
│   ├── models.py            # Data models
│   ├── chat_handler.py      # Chat logic
│   └── requirements.txt
├── frontend/
│   ├── index.html           # Same as AWS version
│   ├── style.css            # Same as AWS version
│   └── app.js               # Updated API endpoint
├── render.yaml              # Render config
├── README.md
└── DEPLOYMENT.md
```

## Migration Checklist

### Pre-Migration
- [ ] Create Render account
- [ ] Get Anthropic API key
- [ ] Test FastAPI app locally
- [ ] Test PostgreSQL locally
- [ ] Verify frontend works with new backend

### Migration
- [ ] Create new GitHub repo (or branch)
- [ ] Copy frontend files
- [ ] Create FastAPI backend
- [ ] Set up PostgreSQL schema
- [ ] Configure render.yaml
- [ ] Push to GitHub
- [ ] Connect Render to repo
- [ ] Set environment variables
- [ ] Deploy

### Post-Migration
- [ ] Test chat functionality
- [ ] Test conversation history
- [ ] Verify database writes
- [ ] Check error handling
- [ ] Monitor costs
- [ ] Update documentation

## Cost Comparison

### AWS Version
- Lambda: $0.20/month
- API Gateway: $0.10/month
- DynamoDB: $0.25/month
- S3: $0.50/month
- **Total: ~$1-2/month** + Anthropic API

### Render Version
- Web Service (Starter): $7/month
- PostgreSQL (Starter): Included
- Static Site: Free
- **Total: $7/month** + Anthropic API

**Trade-off**: Pay $5 more for simpler deployment and management

## Timeline

### Week 1: Setup
- Day 1-2: Create FastAPI backend
- Day 3-4: Set up PostgreSQL
- Day 5: Test locally

### Week 2: Deploy
- Day 1-2: Configure Render
- Day 3-4: Deploy and test
- Day 5: Documentation

### Week 3: Polish
- Day 1-2: UI improvements
- Day 3-4: Error handling
- Day 5: Launch

## Success Criteria

- [ ] Deployment takes < 5 minutes
- [ ] No AWS knowledge required
- [ ] Chat works identically to AWS version
- [ ] Costs are predictable
- [ ] Documentation is clear

## Lessons from AWS Version to Apply

1. **Pre-flight checks**: Validate environment variables before deploy
2. **Clear errors**: Show actionable error messages
3. **Self-testing**: Include health check endpoint
4. **Documentation**: Every step documented with examples
5. **Simplicity**: Fewer moving parts = more reliable

## Next Steps

1. Clone AWS version
2. Create `render-version/` directory
3. Implement FastAPI backend
4. Set up PostgreSQL
5. Test locally
6. Deploy to Render
7. Document everything

**Goal**: Make Render version 10x easier to deploy than AWS version
