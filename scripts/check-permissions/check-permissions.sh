#!/bin/bash

set -euo pipefail

echo "Checking AWS permissions needed to deploy and teardown e-bank resources..."

PRINCIPAL_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Current AWS principal ARN: $PRINCIPAL_ARN"
echo "AWS Account ID: $ACCOUNT_ID"

declare -A SERVICES_ACTIONS=(
  # Creation permissions from before
  [S3]="s3:CreateBucket s3:PutBucketPolicy s3:PutPublicAccessBlock s3:GetBucketLocation s3:PutObject s3:GetObject s3:DeleteObject s3:DeleteBucket"
  [IAM]="iam:CreateRole iam:PutRolePolicy iam:AttachRolePolicy iam:PassRole iam:GetRole"
  [LAMBDA]="lambda:CreateFunction lambda:AddPermission lambda:GetFunction lambda:DeleteFunction"
  [COGNITO]="cognito-idp:CreateUserPool cognito-idp:CreateUserPoolClient cognito-identity:CreateIdentityPool cognito-identity:SetIdentityPoolRoles"
  [APIGATEWAY]="apigateway:CreateRestApi apigateway:CreateResource apigateway:PutMethod apigateway:PutIntegration apigateway:CreateDeployment apigateway:CreateUsagePlan apigateway:CreateApiKey apigateway:CreateUsagePlanKey apigateway:DeleteRestApi"
  [CLOUDFORMATION]="cloudformation:DeleteStack cloudformation:DescribeStacks cloudformation:ListStacks"
)

for SERVICE in "${!SERVICES_ACTIONS[@]}"; do
  echo ""
  echo "Checking permissions for $SERVICE..."

  ACTIONS=${SERVICES_ACTIONS[$SERVICE]}
  
  RESPONSE=$(aws iam simulate-principal-policy \
    --policy-source-arn "$PRINCIPAL_ARN" \
    --action-names $ACTIONS \
    --output json)

  DENIED_ACTIONS=$(echo "$RESPONSE" | jq -r '.EvaluationResults[] | select(.EvalDecision!="allowed") | .EvalActionName')

  if [ -z "$DENIED_ACTIONS" ]; then
    echo "  All required permissions granted for $SERVICE."
  else
    echo "  Missing permissions for $SERVICE:"
    echo "$DENIED_ACTIONS" | sed 's/^/    - /'
  fi
done

echo ""
echo "Permission check complete."
