provider "aws" {
  region = "us-west-2" # Replace with your desired AWS region
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = "citrux-demo-eks-cluster"
  cluster_version = "1.30"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = 50
    instance_types         = ["t3.medium"]
    vpc_security_group_ids = [aws_security_group.node_group.id]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "my-eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_security_group" "node_group" {
  name_prefix = "eks-node-group-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
    description     = "Allow all inbound traffic within the node group"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "Allow all outbound traffic"
  }

  tags = {
    Name                                           = "eks-node-group-sg"
    "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
  }
}
