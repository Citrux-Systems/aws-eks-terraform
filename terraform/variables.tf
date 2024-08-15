variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

data "aws_availability_zones" "available" {}

locals {
  name            = "citrux-demo-eks-${random_string.suffix.result}"
  region          = var.region
  cluster_version = "1.30"
  instance_types  = ["t2.medium"] # can be multiple, comma separated

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GitHubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
  namespace = "ecommerce"
}