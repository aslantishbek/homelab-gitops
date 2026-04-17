resource "null_resource" "k3s_install" {
  connection {
    type        = "ssh"
    host        = var.host
    user        = var.user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "command -v k3s || curl -sfL https://get.k3s.io | sh -",
      "sudo systemctl enable --now k3s",
      "mkdir -p $HOME/.kube",
      "sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config",
      "sudo chown $(id -u) $HOME/.kube/config",
      "kubectl wait --for=condition=Ready node --all --timeout=120s",
    ]
  }

  triggers = {
    always_run = timestamp()
  }
}
