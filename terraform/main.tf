module "vpc" {
  source = "./modules/vpc"
  name   = local.name
  vpc_cidr = local.vpc_cidr
  azs = local.azs
  tags = local.tags
}
module "eks" {
  source = "./modules/eks"
  region = var.region
  name = local.name
  cluster_version = local.cluster_version
  instance_types = local.instance_types
  vpc_id = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  tags = local.tags
  namespace = local.namespace
}