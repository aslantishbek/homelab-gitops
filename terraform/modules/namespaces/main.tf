terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

locals {
  namespaces = toset(["ai", "apps", "games", "media", "monitoring", "networking", "external-secrets"])
}

resource "kubernetes_namespace" "this" {
  for_each = local.namespaces

  metadata {
    name = each.key
    labels = {
      "managed-by" = "terraform"
    }
  }
}
