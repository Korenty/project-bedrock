# ==============================================================================
# AWS EKS Cluster Configuration - Production-Grade (t3.large)
# ==============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = "project-bedrock-cluster"
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  # ----------------------------------------------------------------------------
  # Core Cluster Addons
  # ----------------------------------------------------------------------------
  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    amazon-cloudwatch-observability = {
      most_recent              = true
      service_account_role_arn = module.irsa-addon-cloudwatch.iam_role_arn
    }
  }

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  enable_cluster_creator_admin_permissions = false

  # ----------------------------------------------------------------------------
  # EKS Managed Node Group
  # ----------------------------------------------------------------------------
  eks_managed_node_groups = {
    bedrock_nodes = {
      name = "bedrock-ng"

      iam_role_name            = "bedrock-node-role"
      iam_role_use_name_prefix = false

      instance_types = ["t3.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      subnet_ids = module.vpc.private_subnets

      # FIXED: Upgraded to AL2023 to match Kubernetes 1.34 requirements
      ami_type      = "AL2023_x86_64_STANDARD"
      capacity_type = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        CloudWatchAgentServerPolicy        = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        AWSXrayWriteOnlyAccess             = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
      }

      tags = {
        Name = "bedrock-ng"
      }
    }
  }

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# IRSA Role for CloudWatch Observability Addon
# ------------------------------------------------------------------------------
module "irsa-addon-cloudwatch" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "bedrock-cloudwatch-addon-role"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    ex = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "amazon-cloudwatch:cloudwatch-agent"
      ]
    }
  }

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# ==============================================================================
# STATIC EKS ACCESS ENTRIES (Authorizes Both Local and Pipeline Identities)
# ==============================================================================

# 1. Explicit Cluster Admin Access for Your Local AWS Root Account
resource "aws_eks_access_entry" "root_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::475418221916:root"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "root_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::475418221916:root"

  access_scope {
    type = "cluster"
  }
}

# 2. Explicit Cluster Admin Access for Your GitHub Actions Pipeline User
resource "aws_eks_access_entry" "pipeline_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::475418221916:user/bedrock-terraform-pipeline"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "pipeline_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::475418221916:user/bedrock-terraform-pipeline"

  access_scope {
    type = "cluster"
  }
}