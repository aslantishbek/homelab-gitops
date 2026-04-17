terraform {
  required_version = ">= 1.5"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.3"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "null" {}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = "default"
}

provider "flux" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = "default"
  }
  git = {
    url = "ssh://git@github.com/${var.github_owner}/${var.github_repo}.git"
    ssh = {
      username    = "git"
      private_key = file(var.ssh_private_key_path)
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}
