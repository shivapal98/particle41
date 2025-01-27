# SimpleTimeService ECS Deployment

## Push Docker Image to ECR
1. Navigate to the `App_Task1/` directory under the PARTICLE41 directory.
2. Run the following commands:
   ```bash
   aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
   docker build -t simpletime-service .
   docker tag simpletime-service:latest <ecr_repository_url>:latest
   docker push <ecr_repository_url>:latest


## Deployment Steps
1. Install Terraform CLI.
2. Set up AWS credentials with access to manage infrastructure.
3. Navigate to the `Terraform_Task2/` directory under the PARTICLE41.
4. Run the following commands:
   ```bash
   terraform init
   terraform plan
   terraform apply
