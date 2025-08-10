#!/bin/bash

## Delete Lambda S3 Bucket
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="e-bank-lambda-function-$ACCOUNT_ID"

echo "Deleting all objects from bucket: $BUCKET_NAME"
aws s3 rm "s3://$BUCKET_NAME" --recursive

echo "Deleting bucket: $BUCKET_NAME"
aws s3api delete-bucket --bucket "$BUCKET_NAME"