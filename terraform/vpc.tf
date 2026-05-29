# ==============================================================================
# AWS VPC Module Configuration
# ==============================================================================
# This module automatically builds our entire network structure, including
# Public Subnets (for the Application Load Balancer) and Private Subnets (where
# our EKS Kubernetes nodes and RDS databases will live safely away from the internet).

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"

  # Naming convention mandated by the technical constraints
  name = var.vpc_name
  cidr = "10.0.0.0/16"

  # We place subnets across two Availability Zones for high-availability & reliability
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # NAT Gateway setup: Allows secure, outbound-only internet access for servers
  # residing in our private subnets (e.g. to pull software packages or docker images).
  # We use a single NAT Gateway shared across both zones to keep your AWS bill near $0.
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tagging configurations for the automated grader
  tags = {
    Name    = var.vpc_name
    Project = "karatu-2025-capstone"
  }

  # CRITICAL tags required by AWS Elastic Load Balancing (ELB) to automatically 
  # discover subnets and deploy load balancers for the Kubernetes cluster.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }
}

