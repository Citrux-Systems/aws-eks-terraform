# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "citrux-demo-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "citrux-demo-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.auth.token
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

resource "kubernetes_namespace" "ecommerce" {
  metadata {
    name = "ecommerce"
  }
}

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

#Auto Load Balancer policy
# resource "aws_iam_policy" "alb_policy" {
#   name        = "ALBIngressControllerIAMPolicy"
#   description = "IAM policy for ALB Ingress Controller"
#   policy      = "${file("alb_policy.json")}"
# }

# resource "aws_iam_role" "alb_role" {
#   name               = "ALBIngressControllerIAMRole"
#   assume_role_policy = <<EOF
#   {
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Effect": "Allow",
#         "Principal": {
#           "Service": "eks.amazonaws.com"
#         },
#         "Action": "sts:AssumeRole"
#       }
#     ]
#   }
#   EOF
# }

# resource "aws_iam_role_policy_attachment" "alb_policy_attachment" {
#   policy_arn = aws_iam_policy.alb_policy.arn
#   role       = aws_iam_role.alb_role.name
#   depends_on = [ aws_iam_role.alb_role ]
# }

# resource "aws_iam_role_policy_attachment" "alb-ingress-controller" {
#   role       = aws_iam_role.alb_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   depends_on = [ aws_iam_role.alb_role ]
# }


# resource "kubernetes_service_account" "alb_ingress_controller" {
#   metadata {
#     name      = "alb-ingress-controller"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.alb_role.arn
#     }
#   }
# }

module "alb_ingress_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name                     = "ALBIngressControllerIAMRole-${module.eks.cluster_name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:alb-ingress-controller"]
    }
  }
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_ingress_controller.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "alb-controller" {
  name = "alb-ingress-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  depends_on = [ kubernetes_service_account.service_account ]

  set {
    name = "region"
    value = var.region
  }

  set {
    name = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name = "image.repository"
    value = "602401143452.dkr.ecr.${var.region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name = "serviceAccount.create"
    value = "false"
  }

  set {
    name = "serviceAccount.name"
    value = "alb-ingress-controller"
  }

  set {
    name = "clusterName"
    value = module.eks.cluster_name
  }
}
# module "cluster_autoscaler_irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "5.3.1"

#   role_name                        = "cluster-autoscaler"
#   attach_cluster_autoscaler_policy = true
#   cluster_autoscaler_cluster_ids   = [module.eks.cluster_id]

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:cluster-autoscaler"]
#     }
#   }
# }

# provider "kubectl" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   load_config_file       = false

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
#     command     = "aws"
#   }
# }

# resource "kubectl_manifest" "service_account" {
#   yaml_body = <<-EOF
#     apiVersion: v1
#     kind: ServiceAccount
#     metadata:
#       name: cluster-autoscaler
#       namespace: kube-system
#       annotations:
#         eks.amazonaws.com/role-arn: ${module.cluster_autoscaler_irsa_role.iam_role_arn}
#   EOF
# }

# resource "kubectl_manifest" "role" {
#   yaml_body = <<-EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: Role
# metadata:
#   name: cluster-autoscaler
#   namespace: kube-system
#   labels:
#     k8s-addon: cluster-autoscaler.addons.k8s.io
#     k8s-app: cluster-autoscaler
# rules:
#   - apiGroups: [""]
#     resources: ["configmaps"]
#     verbs: ["create","list","watch"]
#   - apiGroups: [""]
#     resources: ["configmaps"]
#     resourceNames: ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
#     verbs: ["delete", "get", "update", "watch"]
# EOF
# }

# resource "kubectl_manifest" "role_binding" {
#   yaml_body = <<-EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: RoleBinding
# metadata:
#   name: cluster-autoscaler
#   namespace: kube-system
#   labels:
#     k8s-addon: cluster-autoscaler.addons.k8s.io
#     k8s-app: cluster-autoscaler
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: Role
#   name: cluster-autoscaler
# subjects:
#   - kind: ServiceAccount
#     name: cluster-autoscaler
#     namespace: kube-system
# EOF
# }

# resource "kubectl_manifest" "cluster_role" {
#   yaml_body = <<-EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: cluster-autoscaler
#   labels:
#     k8s-addon: cluster-autoscaler.addons.k8s.io
#     k8s-app: cluster-autoscaler
# rules:
#   - apiGroups: [""]
#     resources: ["events", "endpoints"]
#     verbs: ["create", "patch"]
#   - apiGroups: [""]
#     resources: ["pods/eviction"]
#     verbs: ["create"]
#   - apiGroups: [""]
#     resources: ["pods/status"]
#     verbs: ["update"]
#   - apiGroups: [""]
#     resources: ["endpoints"]
#     resourceNames: ["cluster-autoscaler"]
#     verbs: ["get", "update"]
#   - apiGroups: [""]
#     resources: ["nodes"]
#     verbs: ["watch", "list", "get", "update"]
#   - apiGroups: [""]
#     resources:
#       - "namespaces"
#       - "pods"
#       - "services"
#       - "replicationcontrollers"
#       - "persistentvolumeclaims"
#       - "persistentvolumes"
#     verbs: ["watch", "list", "get"]
#   - apiGroups: ["extensions"]
#     resources: ["replicasets", "daemonsets"]
#     verbs: ["watch", "list", "get"]
#   - apiGroups: ["policy"]
#     resources: ["poddisruptionbudgets"]
#     verbs: ["watch", "list"]
#   - apiGroups: ["apps"]
#     resources: ["statefulsets", "replicasets", "daemonsets"]
#     verbs: ["watch", "list", "get"]
#   - apiGroups: ["storage.k8s.io"]
#     resources: ["storageclasses", "csinodes", "csidrivers", "csistoragecapacities"]
#     verbs: ["watch", "list", "get"]
#   - apiGroups: ["batch", "extensions"]
#     resources: ["jobs"]
#     verbs: ["get", "list", "watch", "patch"]
#   - apiGroups: ["coordination.k8s.io"]
#     resources: ["leases"]
#     verbs: ["create"]
#   - apiGroups: ["coordination.k8s.io"]
#     resourceNames: ["cluster-autoscaler"]
#     resources: ["leases"]
#     verbs: ["get", "update"]
# EOF
# }

# resource "kubectl_manifest" "cluster_role_binding" {
#   yaml_body = <<-EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: cluster-autoscaler
#   labels:
#     k8s-addon: cluster-autoscaler.addons.k8s.io
#     k8s-app: cluster-autoscaler
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: cluster-autoscaler
# subjects:
#   - kind: ServiceAccount
#     name: cluster-autoscaler
#     namespace: kube-system
# EOF
# }

# resource "kubectl_manifest" "deployment" {
#   yaml_body = <<-EOF
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: cluster-autoscaler
#   namespace: kube-system
#   labels:
#     app: cluster-autoscaler
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       app: cluster-autoscaler
#   template:
#     metadata:
#       labels:
#         app: cluster-autoscaler
#     spec:
#       priorityClassName: system-cluster-critical
#       securityContext:
#         runAsNonRoot: true
#         runAsUser: 65534
#         fsGroup: 65534
#       serviceAccountName: cluster-autoscaler
#       containers:
#         - image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.26.2
#           name: cluster-autoscaler
#           resources:
#             limits:
#               cpu: 100m
#               memory: 600Mi
#             requests:
#               cpu: 100m
#               memory: 600Mi
#           command:
#             - ./cluster-autoscaler
#             - --v=4
#             - --stderrthreshold=info
#             - --cloud-provider=aws
#             - --skip-nodes-with-local-storage=false
#             - --expander=least-waste
#             - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${module.eks.cluster_name}
#           volumeMounts:
#             - name: ssl-certs
#               mountPath: /etc/ssl/certs/ca-certificates.crt
#               readOnly: true
#       volumes:
#         - name: ssl-certs
#           hostPath:
#             path: "/etc/ssl/certs/ca-bundle.crt"
# EOF
# }
