# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {

  # cloud {
  #   workspaces {
  #     name = "learn-terraform-eks"
  #   }
  # }

  required_providers {

    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }

  required_version = "~> 1.3"
}

