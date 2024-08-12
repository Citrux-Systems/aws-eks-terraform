variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_endpoint" {
  description = "value of the EKS cluster endpoint"
  type        = string
}

variable "eks_cluster_certificate_authority" {
  description = "value of the EKS cluster certificate authority"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "value of the EKS OIDC provider ARN"
  type        = string
}