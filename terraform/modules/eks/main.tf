module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.32.1"

  cluster_name    = var.name
  cluster_version = var.cluster_version

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnets

  managed_node_groups = {
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

module "eks_blueprints_kubernetes_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks_blueprints.eks_cluster_id
  cluster_endpoint  = module.eks_blueprints.eks_cluster_endpoint
  cluster_version   = module.eks_blueprints.eks_cluster_version
  oidc_provider_arn = module.eks_blueprints.oidc_provider

  # EKS Managed Add-ons
  eks_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  # K8S Add-ons
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_aws_cloudwatch_metrics       = false

  tags = var.tags

}

# To update local kubeconfig with new cluster details
resource "null_resource" "kubeconfig" {
  depends_on = [module.eks_blueprints_kubernetes_addons]
  provisioner "local-exec" {
    command = "aws eks --region ${var.region}  update-kubeconfig --name $AWS_CLUSTER_NAME"
    environment = {
      AWS_CLUSTER_NAME = var.name
    }
  }
}

resource "null_resource" "create_namespace" {
  depends_on = [module.eks_blueprints_kubernetes_addons]
  provisioner "local-exec" {
    command = "kubectl create namespace ${var.namespace}"
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }
}

data "aws_eks_cluster" "eks_cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

output "eks_cluster_endpoint" {
  # value = data.aws_eks_cluster.eks_cluster.endpoint
  value = module.eks_blueprints.eks_cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  # value = data.aws_eks_cluster.eks_cluster.certificate_authority[0].data
  value = module.eks_blueprints.eks_cluster_certificate_authority_data
}

output "eks_cluster_name" {
  # value = data.aws_eks_cluster.eks_cluster.name
  value = module.eks_blueprints.eks_cluster_id
}
