output "node_status" {
  value      = "ready"
  depends_on = [null_resource.k3s_install]
}
