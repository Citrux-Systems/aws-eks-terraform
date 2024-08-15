variable "region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "name for the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "instance_types" {
  description = "EC2 instance types"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}