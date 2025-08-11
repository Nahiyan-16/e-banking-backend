#!/bin/bash

# Teardown CloudFormation Stacks for eBank Backend
set -e

# Note: S3 buckets must be empty before deletion

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_DATA_BUCKET="e-bank-user-data-${AWS_ACCOUNT_ID}"
echo "Checking for user data bucket: $USER_DATA_BUCKET"

if aws s3api head-bucket --bucket "$USER_DATA_BUCKET" 2>/dev/null; then
    echo "Deleting '$USER_DATA_BUCKET' ..."
    aws s3 rm s3://$USER_DATA_BUCKET --recursive
    echo "Deleting bucket: $USER_DATA_BUCKET"
    aws s3api delete-bucket --bucket "$USER_DATA_BUCKET"
    echo "Deleted bucket '$USER_DATA_BUCKET'."
else
    echo "Bucket '$USER_DATA_BUCKET' does not exist."
fi

LAMBDA_BUCKET="e-bank-lambda-function-${AWS_ACCOUNT_ID}"
echo "Checking for lambda function bucket: $LAMBDA_BUCKET"
if aws s3api head-bucket --bucket "$LAMBDA_BUCKET" 2>/dev/null; then
    echo "Deleting '$LAMBDA_BUCKET' ..."
    aws s3 rm s3://$LAMBDA_BUCKET --recursive
    aws s3api delete-bucket --bucket "$LAMBDA_BUCKET"
    echo "Deleted bucket '$LAMBDA_BUCKET'."
else
    echo "Bucket '$LAMBDA_BUCKET' does not exist."
    exit 1
fi

# Delete API Gateway Stack
echo "Deleting eBankBackendStack..."
aws cloudformation delete-stack --stack-name eBankBackendStack
aws cloudformation wait stack-delete-complete --stack-name eBankBackendStack
echo "Deleted eBankBackendStack"

echo "eBank backend CloudFormation stack have been deleted."
echo "S3 buckets have been deleted."