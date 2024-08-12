output "eks_cluster_name" {
  description = "EKS cluster name"
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "value of the EKS cluster endpoint"
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "value of the EKS cluster certificate authority"
  value = module.eks.cluster_certificate_authority
}

output "eks_oidc_provider_arn" {
  description = "value of the EKS OIDC provider ARN"
  value = module.eks.oidc_provider_arn
}