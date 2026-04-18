module "k3s" {
  source = "./modules/k3s"
}

module "namespaces" {
  source     = "./modules/namespaces"
  depends_on = [module.k3s]
}

module "flux" {
  source = "./modules/flux"

  github_token  = var.github_token
  github_owner  = var.github_owner
  github_repo   = var.github_repo
  github_branch = var.github_branch

  depends_on = [module.namespaces]
}
