terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }
    nullres = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    # TODO: cut bellow
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }

    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    # }
  }

  required_version = "~> 1.3"
}

