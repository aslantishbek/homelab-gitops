output "k3s_node_status" {
  value = module.k3s.node_status
}

output "flux_ready" {
  value = module.flux.ready
}
