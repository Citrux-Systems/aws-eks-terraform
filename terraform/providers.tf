provider "aws" {
  region = local.region
}

data "aws_eks_cluster" "eks_cluster" {
  # name = local.name
  # depends_on = [ module.eks ]
  name = module.eks.eks_cluster_name
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = module.eks.eks_cluster_name
}

# Kubernetes provider
# You should **not** schedule deployments and services in this workspace.
# This keeps workspaces modular (one for provision EKS, another for scheduling
# Kubernetes resources) as per best practices.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster.token
  # host                   = module.eks.eks_cluster_endpoint
  # cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.eks_cluster.name]
    # args = ["eks", "get-token", "--cluster-name", local.name]
  }
}
