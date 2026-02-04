# Container Image Deployment Migration

## What Changed?

The AWS Coding Copilot Lambda function is now deployed as a **container image** instead of a ZIP package.

## Why?

1. **Larger Size Limit**: Container images support up to 10GB (vs 250MB for ZIP)
2. **Better Dependencies**: No more issues with compiled binaries or native extensions
3. **Consistency**: Same container from development to production
4. **Modern Practice**: Aligns with container-native AWS workflows
5. **No Binary Validation**: Eliminates "Binary validation failed for python" errors

## Technical Changes

### Before (ZIP Package)
```yaml
# template.yaml
Globals:
  Function:
    Runtime: python3.12
    
Resources:
  CodingCopilotFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: ../lambda/
      Handler: chat_handler.lambda_handler
```

Build: `sam build --use-container`

### After (Container Image)
```yaml
# template.yaml
Globals:
  Function:
    # Runtime removed (not compatible with Image type)
    
Resources:
  CodingCopilotFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
    Metadata:
      Dockerfile: Dockerfile
      DockerContext: ../lambda/
      DockerTag: v1
```

Build: `sam build`

## New File: backend/lambda/Dockerfile

```dockerfile
FROM public.ecr.aws/lambda/python:3.12
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt
COPY chat_handler.py ${LAMBDA_TASK_ROOT}/
CMD ["chat_handler.lambda_handler"]
```

## For Users

**No changes required!** The deployment process is exactly the same:

```bash
./deploy-safe.sh
```

The script automatically builds the container image and deploys it.

## Benefits You'll See

- ✅ More reliable deployments
- ✅ Faster builds (Docker layer caching)
- ✅ Easier local testing (run the same container locally)
- ✅ No Python version compatibility issues
- ✅ Better dependency management

## Local Testing

You can now test the Lambda function locally using the same container:

```bash
cd backend/lambda
docker build -t coding-copilot-lambda .
docker run -p 9000:8080 coding-copilot-lambda

# In another terminal, invoke the function
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"body": "{\"message\":\"Hello\",\"conversationId\":\"test-123\"}"}'
```

## Migration Notes

This is a **transparent migration** - the Lambda function behavior is identical, only the packaging method changed.

### If You Have an Existing Deployment

1. Run `./deploy-safe.sh` - it will update to container image deployment
2. AWS will create a new container image repository in ECR
3. Your existing Lambda function will be updated in-place
4. No downtime or data loss

### Rollback (if needed)

If you need to rollback to ZIP deployment:
1. Revert the changes to `template.yaml`
2. Run `sam build --use-container && sam deploy`

## Learn More

- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [SAM Container Image Support](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-using-build.html)
