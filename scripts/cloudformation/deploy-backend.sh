#!/bin/bash
## Deploy CloudFormation Stacks for eBank Backend

set -e

# Deploy S3 Stack
aws cloudformation deploy \
  --stack-name eBankS3Stack \
  --template-file s3-template.yml \
  --parameter-overrides StackName=eBankStack \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy Lambda Stack

aws cloudformation deploy \
  --stack-name eBankLambdaStack \
  --template-file lambda-template.yml \
  --parameter-overrides StackName=eBankStack \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy Cognito Stack

aws cloudformation deploy \
  --stack-name eBankCognitoStack \
  --template-file cognito-template.yml \
  --parameter-overrides StackName=eBankStack \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy API Gateway Stack

aws cloudformation deploy \
  --stack-name eBankApiStack \
  --template-file api-gateway-template.yml \
  --parameter-overrides StackName=eBankStack StageName=prod \
  --capabilities CAPABILITY_NAMED_IAM

