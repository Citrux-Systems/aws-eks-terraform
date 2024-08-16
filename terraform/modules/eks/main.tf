module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_name    = var.name
  cluster_version = var.cluster_version
  cluster_endpoint_public_access = true

  vpc_id             = var.vpc_id
  subnet_ids = var.private_subnets
  control_plane_subnet_ids = var.private_subnets

  # EKS Addons
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  eks_managed_node_group_defaults = {
    # Needed by the aws-ebs-csi-driver
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
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

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name        = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # K8S Add-ons
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = var.vpc_id
      },
      {
        name  = "podDisruptionBudget.maxUnavailable"
        value = 1
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      }
    ]
  }
  enable_metrics_server               = true
  enable_aws_cloudwatch_metrics       = false

  tags = var.tags
}

# To update local kubeconfig with new cluster details
resource "null_resource" "kubeconfig" {
  depends_on = [module.eks_blueprints_addons]
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