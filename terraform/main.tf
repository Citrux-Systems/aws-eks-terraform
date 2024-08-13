module "eks" {
  source = "./modules/eks"
  region = var.region
}

module "alb" {
  source = "./modules/alb"
  region = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id = module.eks.vpc_id
  cluster_name = module.eks.cluster_name
}

module "kubernetes" {
  source = "./modules/kubernetes"
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_token = module.eks.cluster_token
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
} 