terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "k3s_install" {
  provisioner "local-exec" {
    command = <<-SCRIPT
      command -v k3s || curl -sfL https://get.k3s.io | sh -
      sudo systemctl enable --now k3s
      mkdir -p $HOME/.kube
      sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
      sudo chown $(id -u) $HOME/.kube/config
      kubectl wait --for=condition=Ready node --all --timeout=120s
    SCRIPT
  }

  triggers = {
    always_run = timestamp()
  }
}
