#!/bin/bash

## Set region
REGION="us-east-1"

## Public Lambda Code on S3
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="e-bank-lambda-function-$ACCOUNT_ID"
FILE_PATH="./index.zip"

echo "Using bucket name: $BUCKET_NAME"
echo "Uploading file: $FILE_PATH"

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File $FILE_PATH does not exist."
  exit 1
fi

echo "Creating bucket: $BUCKET_NAME in region $REGION..."
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"

echo "Uploading $FILE_PATH to s3://$BUCKET_NAME/index.zip..."
aws s3 cp "$FILE_PATH" "s3://$BUCKET_NAME/index.zip"

echo "Setting bucket policy for public read access..."
cat > public-read-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file://public-read-policy.json
rm public-read-policy.json

echo "Disabling public access block settings..."
aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo "Setup complete. Your file is publicly accessible at:"
echo "https://$BUCKET_NAME.s3.amazonaws.com/index.zip"