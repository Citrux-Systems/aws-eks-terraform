module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_name    = var.name
  cluster_version = var.cluster_version
  cluster_endpoint_public_access = true

  vpc_id             = var.vpc_id
  subnet_ids = var.private_subnets
  control_plane_subnet_ids = var.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    one = {
      node_group_name = "node-group-1"
      instance_types  = var.instance_types
      min_size        = 1
      max_size        = 3
      desired_size    = 2
      subnet_ids      = var.private_subnets
    }
    two = {
      node_group_name = "node-group-2"
      instance_types  = var.instance_types
      min_size        = 1
      max_size        = 2
      desired_size    = 1
      subnet_ids      = var.private_subnets
    }
  }

  tags = var.tags
}

# To update local kubeconfig with new cluster details
resource "null_resource" "kubeconfig" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks --region ${var.region}  update-kubeconfig --name $AWS_CLUSTER_NAME"
    environment = {
      AWS_CLUSTER_NAME = var.name
    }
  }
}

resource "null_resource" "create_namespace" {
  depends_on = [null_resource.kubeconfig]
  provisioner "local-exec" {
    command = "kubectl create namespace ${var.namespace}"
  }
}