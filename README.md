# InnovateMart - Project Bedrock

This repository contains the Infrastructure as Code (IaC) and Application Deployment configurations for Project Bedrock to deploy the Retail Store Application on Amazon EKS.

## Architecture

```mermaid
graph TD
    subgraph "AWS Cloud (us-east-1)"
        subgraph "VPC: project-bedrock-vpc"
            ALB[Application Load Balancer]
            
            subgraph "Public Subnets"
                NAT[NAT Gateway]
            end
            
            subgraph "Private Subnets"
                EKS[EKS Cluster: project-bedrock]
                EKS_NODES[Node Groups: t3.large]
                
                RDS_MYSQL[(RDS MySQL: catalog)]
                RDS_POSTGRES[(RDS Postgres: orders)]
            end
        end
        
        S3[S3 Bucket: bedrock-assets-alt-soe-025-3173]
        LAMBDA[Lambda: bedrock-asset-processor]
        DYNAMO[(DynamoDB: items)]
        
        ACM[ACM Certificate]
        CW[CloudWatch Logs]
    end
    
    Internet((Internet)) -->|HTTPS| ALB
    ALB -->|HTTP| EKS_NODES
    
    EKS_NODES --> RDS_MYSQL
    EKS_NODES --> RDS_POSTGRES
    EKS_NODES --> DYNAMO
    
    S3 -.->|Event Notification| LAMBDA
    LAMBDA -.->|Logging| CW
    EKS_NODES -.->|Observability| CW
    EKS -.->|Control Plane Logs| CW
    
    ACM -.-> ALB
```

## Deployment Guide

1. **Triggering the Pipeline**: The CI/CD pipeline triggers automatically using GitHub Actions. 
   - Opening a Pull Request to `main` runs `terraform plan`.
   - Merging the PR into `main` automatically runs `terraform apply` to deploy all resources.

2. **Accessing the Retail Store**: 
   - The application is exposed securely via AWS Application Load Balancer using an ACM TLS certificate.
   - Run `kubectl get ingress -n retail-app` to retrieve the ALB domain endpoint.
   - Navigate to `https://<ALB-DOMAIN>` in your browser.

## Security & Grading Credentials

- The IAM User `bedrock-dev-view` has been deployed enabling secure ReadOnly access for developers. 
- Infrastructure generates `grading.json` via terraform outputs.

### Manual Helm Deployment (Bonus Objective 5.1 Verification)

If not using Terraform to apply the Helm release automatically, you can deploy the wrapped chart with a single command passing the custom data layer overrides:

```bash
helm upgrade --install retail-app ./kubernetes/retail-store-sample-chart \
  --namespace retail-app --create-namespace \
  -f ./kubernetes/custom-values.yaml
```
*(Ensure all placeholder values in `custom-values.yaml` and Kubernetes Secrets are fulfilled using your provisioned AWS resources).*
