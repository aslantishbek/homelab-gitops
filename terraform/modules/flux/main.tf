terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.3"
    }
  }
}

resource "flux_bootstrap_git" "this" {
  path = "cluster"
}
