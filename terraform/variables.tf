variable "homelab_host" {
  description = "Homelab SSH host alias"
  default     = "homelab"
}

variable "homelab_user" {
  description = "Homelab SSH user"
  default     = "aslantishbek"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  default     = "~/.ssh/id_rsa"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig"
  default     = "~/.kube/config"
}

variable "github_token" {
  description = "GitHub PAT (set via TF_VAR_github_token)"
  sensitive   = true
}

variable "github_owner" {
  default = "aslantishbek"
}

variable "github_repo" {
  default = "homelab-gitops"
}

variable "github_branch" {
  default = "main"
}
