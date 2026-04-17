output "ready" {
  value      = true
  depends_on = [flux_bootstrap_git.this]
}
