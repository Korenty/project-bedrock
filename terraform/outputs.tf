# ==============================================================================
# MANDATORY ROOT OUTPUTS FOR AUTOMATED GRADING (Section 1)
# ==============================================================================
# The automated grading engine reads these specific output values from your state file.

output "vpc_id" {
  description = "The ID of the newly created VPC"
  value       = module.vpc.vpc_id
}

output "region" {
  description = "The AWS Region used for this deployment"
  value       = var.aws_region
}

output "cluster_name" {
  description = "The EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The public endpoint URL of your EKS Cluster"
  value       = module.eks.cluster_endpoint
}

output "assets_bucket_name" {
  description = "The unique assets bucket name for S3"
  value       = "bedrock-assets-alt-soe-025-3173"
}