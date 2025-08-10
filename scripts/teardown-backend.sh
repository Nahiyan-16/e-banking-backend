#!/bin/bash

# Teardown CloudFormation Stacks for eBank Backend
set -e

# Delete API Gateway Stack
aws cloudformation delete-stack --stack-name eBankApiStack
aws cloudformation wait stack-delete-complete --stack-name eBankApiStack
echo "Deleted eBankApiStack"

# Delete Cognito Stack
aws cloudformation delete-stack --stack-name eBankCognitoStack
aws cloudformation wait stack-delete-complete --stack-name eBankCognitoStack
echo "Deleted eBankCognitoStack"

# Delete Lambda Stack
aws cloudformation delete-stack --stack-name eBankLambdaStack
aws cloudformation wait stack-delete-complete --stack-name eBankLambdaStack
echo "Deleted eBankLambdaStack"

# Delete S3 Stack

# Note: S3 buckets must be empty before deletion
S3_BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name eBankS3Stack --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)
if [ -n "$S3_BUCKET_NAME" ]; then
  echo "Emptying S3 bucket: $S3_BUCKET_NAME"
  aws s3 rm s3://$S3_BUCKET_NAME --recursive
  aws s3api delete-bucket --bucket $S3_BUCKET_NAME
  echo "Deleted S3 bucket: $S3_BUCKET_NAME"
fi
aws cloudformation delete-stack --stack-name eBankS3Stack
aws cloudformation wait stack-delete-complete --stack-name eBankS3Stack
echo "Deleted eBankS3Stack"

echo "All eBank backend CloudFormation stacks have been deleted."