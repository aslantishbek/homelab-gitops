locals {
  namespaces = toset(["ai", "apps", "games", "media", "networking", "external-secrets"])
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
