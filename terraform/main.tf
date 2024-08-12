module "eks" {
  source = "./modules/eks"
  region = var.region
}

module "alb" {
  source = "./modules/alb"
  eks_cluster_name = module.eks.cluster_name
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_cluster_certificate_authority = module.eks.cluster_certificate_authority
  eks_cluster_endpoint = module.eks.cluster_endpoint
}