#!/bin/bash
## Deploy CloudFormation Stacks for eBank Backend
## This script assumes that you have AWS CLI installed and configured with appropriate permissions.
## Please make sure to cd into the scripts directory before running this script.
## Usage: ./deploy-backend.sh

set -e

## Set region
REGION="us-east-1"

# Checking prequisites
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it to proceed."
    exit 1
fi

# Checking if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null
then
    echo "AWS credentials are not configured. Please configure them to proceed."
    exit 1
fi

# Check if AWS Account has the required permissions
./check-permissions/check-permissions.sh

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Bucket names
LAMBDA_BUCKET="e-bank-lambda-function-${AWS_ACCOUNT_ID}"
USER_DATA_BUCKET="e-bank-user-data-${AWS_ACCOUNT_ID}"

## Public Lambda Code on S3

FILE_PATH_LAMBDA_FUNCTION="./lambda/index.zip"

echo "Using bucket name: $LAMBDA_BUCKET"
echo "Uploading file: $FILE_PATH_LAMBDA_FUNCTION"

if [ ! -f "$FILE_PATH_LAMBDA_FUNCTION" ]; then
  echo "Error: File $FILE_PATH_LAMBDA_FUNCTION does not exist."
  exit 1
fi

# Check if lambda function bucket exists
echo "Checking for lambda function bucket: $LAMBDA_BUCKET"
if aws s3api head-bucket --bucket "$LAMBDA_BUCKET" 2>/dev/null; then
    echo "Bucket '$LAMBDA_BUCKET' exists."
else
    echo "Bucket '$LAMBDA_BUCKET' does not exist."
    echo "Creating bucket: $LAMBDA_BUCKET in region $REGION..."
    if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$LAMBDA_BUCKET" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$LAMBDA_BUCKET" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "Uploading $FILE_PATH_LAMBDA_FUNCTION to s3://$LAMBDA_BUCKET/index.zip..."
    aws s3 cp "$FILE_PATH_LAMBDA_FUNCTION" "s3://$LAMBDA_BUCKET/index.zip"

    echo "Lambda function uploaded successfully to s3://$LAMBDA_BUCKET/index.zip"
fi

# Checking if required template files exist
TEMPLATE=("./cloudformation/backend-template.yml")
for file in "${TEMPLATE[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required template file '$file' does not exist."
        exit 1
    fi
done

# Deploy Backend Stack
aws cloudformation deploy \
  --stack-name eBankBackendStack \
  --template-file ./cloudformation/backend-template.yml \
  --parameter-overrides StackName=eBankStack StageName=prod \
  --capabilities CAPABILITY_NAMED_IAM

if [ $? -ne 0 ]; then
    echo "Failed to deploy eBankBackendStack"
    exit 1
fi
echo "eBankBackendStack deployed successfully."

