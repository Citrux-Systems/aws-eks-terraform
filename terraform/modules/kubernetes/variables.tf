variable "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes"
  type = string
}

variable "cluster_token" {
  description = "the token for the EKS Kubernetes"
  type = string
}

variable "cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS Kubernetes"
  type = string
}