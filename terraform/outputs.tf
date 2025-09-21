# -----------------------
# EKS Cluster Outputs
# -----------------------
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_provider_arn" {
  description = "The OIDC provider ARN for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

# -----------------------
# VPC Outputs
# -----------------------
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnets used by the cluster"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnets used by the cluster"
  value       = module.vpc.public_subnets
}

# -----------------------
# ECR Outputs
# -----------------------
output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.ecr_repo.name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.ecr_repo.repository_url
}

# -----------------------
# IAM Roles Outputs
# -----------------------
output "ebs_csi_irsa_role_arn" {
  description = "IAM role ARN for the EBS CSI driver service account"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler service account"
  value       = module.iam_assumable_role_admin.iam_role_arn
}
