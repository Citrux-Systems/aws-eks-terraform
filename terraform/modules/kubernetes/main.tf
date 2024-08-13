provider "kubernetes" {
  host = var.cluster_endpoint
  token = var.cluster_token
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
}

resource "kubernetes_namespace" "ecommerce" {
  metadata {
    name = "ecommerce"
  }
}