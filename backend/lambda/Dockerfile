# Use AWS Lambda Python 3.12 base image
FROM public.ecr.aws/lambda/python:3.12

# Copy requirements file
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy Lambda function code
COPY chat_handler.py ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD ["chat_handler.lambda_handler"]
