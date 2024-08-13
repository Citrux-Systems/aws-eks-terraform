variable "region" {
  description = "AWS region"
  type = string
}

variable "oidc_provider_arn" {
  description = "The OIDC provider ARN"
  type = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type = string
}

variable "cluster_name" {
  description = "The EKS cluster name"
  type = string
}