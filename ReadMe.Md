# 🏦 e-Banking App — Backend Deployment Guide

## Prerequisites

Before you begin, ensure the following are installed and configured:

- **AWS CLI:** The Amazon Web Services Command Line Interface.
- **AWS CLI Permissions:** The AWS CLI must be configured with the appropriate permissions to create and manage resources.

### Clone the Repo

```bash
git clone https://github.com/YOUR_USERNAME/e-banking-backend.git
cd e-banking-app
```

# OPTION 1:

## Deploying the server to AWS

This section outlines the steps to deploy the backend using AWS services.

1. **Prepare the Lambda Function:**

   - Navigate to the `scripts/lambda` directory.
   - **Optional:** Update the AWS region in the `lambda-function-s3.sh` script if necessary.
   - Run the script `lambda-function-s3.sh` to create an S3 bucket and store the public-facing Lambda function.

2. **Deploy CloudFormation Templates:**
   - Navigate to the `scripts/cloudformation` directory.
   - Run the `deploy-backend.sh` script. This will deploy all of your backend's CloudFormation templates, creating the necessary AWS infrastructure.

# OPTION 2:

## Running the server Locally

This section provides instructions for setting up and running the project on your local machine.

1. **Install Dependencies:**

   - Open your terminal in the project's root directory.
   - Run the following command to install all required dependencies:
     ```
     npm install
     ```

2. **Deploy CloudFormation Templates:**

   - Navigate to the `scripts/cloudformation` directory.
   - Run the `deploy-backend.sh` script. This will deploy all of your backend's CloudFormation templates, creating the necessary AWS infrastructure.

3. **Run the Server:**
   - Once the dependencies are installed, start the local server with this command:
     ```
     node server.mjs
     ```

# Teardown backend

## Teardown the cloudformation stacks and delete all S3 buckets

```sh
cd scripts
chmod +x teardown-backend.sh
./teardown-backend.sh
```
