# homelab-gitops

Single-node k3s homelab on `192.168.68.58` (hostname: `homelab`), managed by Flux v2 GitOps. Terraform handles infrastructure; Flux handles apps.

## Hardware
- CPU: AMD Ryzen 7 5800X3D, 32GB RAM
- GPU: AMD RX 7900 XTX (20GB VRAM) — ROCm, runs Ollama natively
- Storage: 2x NVMe (~1.8TB `/`, ~1.9TB `/home`)

## Repo structure
```
cluster/          # Infrastructure Flux kustomizations (Flux itself, ESO, cert-manager)
  apps-sync.yaml  # Points Flux at ./apps, depends on external-secrets-store
  flux-system/    # Flux controllers + GitRepository
  external-secrets/ # ESO helm release
  external-secrets-store/ # ClusterSecretStore (vaultwarden-backend)
  cert-manager/   # TLS automation
  monitoring/     # kube-prometheus + loki (not yet active)
apps/             # All application manifests (each app = own folder + kustomization.yaml)
terraform/        # Infrastructure as code (k3s install, namespaces, Flux bootstrap)
```

## Namespaces
| Namespace | Purpose |
|-----------|---------|
| `ai` | LiteLLM, Ollama-facing apps, orchestrator, ComfyUI |
| `apps` | User apps: open-webui, vaultwarden, samba, minecraft, 3x-ui, presentation |
| `networking` | Traefik (ingress), AdGuard, cert-manager |
| `external-secrets` | ESO operator + bitwarden-proxy |
| `flux-system` | Flux controllers |
| `games`, `media` | Reserved |

## Ingress pattern
- Controller: **Traefik** (LoadBalancer on 80/443)
- TLS: **cert-manager** with `letsencrypt-prod` ClusterIssuer
- Domain: `*.a-tishbek.info`
- Every ingress needs these annotations:
```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  traefik.ingress.kubernetes.io/router.entrypoints: websecure
  traefik.ingress.kubernetes.io/router.tls: "true"
```

## Secrets pattern
All secrets come from **Vaultwarden** (`vault.a-tishbek.info`) via ESO:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: apps
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: vaultwarden-backend   # uses $.data.login.password from Bitwarden item
  target:
    name: my-secret
  data:
    - secretKey: MY_KEY
      remoteRef:
        key: bitwarden-item-name   # exact name of Login item in Vaultwarden
```
The bitwarden-proxy fetches `$.data.login.password` — item name must match exactly, password field holds the secret value.

## Adding a new app
1. Create `apps/<appname>/` with: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `kustomization.yaml`
2. Add `- <appname>` to `apps/kustomization.yaml`
3. If secret needed: add `external-secret.yaml` + create Login item in Vaultwarden first
4. Commit + push → Flux reconciles automatically (interval: 10m, or force below)

## Force Flux reconcile (run on homelab)
```bash
kubectl annotate gitrepository flux-system -n flux-system reconcile.fluxcd.io/requestedAt=$(date +%s) --overwrite
kubectl get kustomization -n flux-system   # check status
```

## Terraform (run on homelab in ~/homelab-gitops/terraform/)
- State: S3 bucket `homelab-terraform-state-fb33c698` (us-east-1)
- Manages: k3s install, namespaces, Flux bootstrap
- Auth: `TF_VAR_github_token=<pat>` required
- SSH key: `~/.ssh/homelab`
- **Do not `terraform destroy`** — will tear down the cluster

## AI stack (namespace: ai)
| Service | URL | Purpose |
|---------|-----|---------|
| Ollama | `http://192.168.68.58:11434` | Local LLM runtime (host, not k8s) |
| LiteLLM | `litellm.a-tishbek.info` | Unified OpenAI-compatible proxy |
| Orchestrator | `orchestrator.a-tishbek.info` | Local→Claude/Gemini review pipeline |
| Open WebUI | `chat.a-tishbek.info` | Chat UI (connects to both Ollama + LiteLLM) |

LiteLLM models: `claude-sonnet`, `claude-opus`, `claude-haiku`, `gemini-2.5-pro`, `gemini-2.0-flash`, `qwen3.5-35b`, `qwen3-coder-30b`, `gemma4-31b`

Orchestrator models: `orchestrated`, `orchestrated-fast`, `orchestrated-heavy`, `orchestrated-code`, `orchestrated-gemini`

## Common services
| App | URL | Notes |
|-----|-----|-------|
| Vaultwarden | `vault.a-tishbek.info` | Self-hosted Bitwarden |
| Jellyfin | `jellyfin.a-tishbek.info` | Media server |
| Samba | `192.168.68.58:445` | File sharing (k8s pod, force user=root) |
| Minecraft | Port 25565 | LoadBalancer |
| 3x-ui | Ports 2053, 26789 | Xray proxy panel |

## Key gotchas
- Flux uses `ClusterFirst` DNS — if you ever see `dnsPolicy: None` on flux pods, patch it back
- `qwen3.5-abliterated` is in Ollama but excluded from LiteLLM (not needed in prod)
- ComfyUI runs on WSL PC (RTX 5080), NOT on homelab
- Samba uses `servercontainers/samba` — env vars use `_SPACE_` not spaces: `SAMBA_GLOBAL_CONFIG_server_SPACE_min_SPACE_protocol`
