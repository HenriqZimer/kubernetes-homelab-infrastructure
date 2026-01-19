# 🏠 Kubernetes Homelab Infrastructure

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3.14+-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Vault](https://img.shields.io/badge/Vault-1.21+-000000?logo=vault&logoColor=white)](https://www.vaultproject.io/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Latest-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready, self-hosted Kubernetes cluster infrastructure for homelab environments with enterprise-grade security, monitoring, and secrets management.

## ✨ Features

### 🔒 Security & Secrets Management
- **HashiCorp Vault** - Centralized secrets management
- **External Secrets Operator** - Automatic secret synchronization from Vault
- **Cert-Manager** - Automated TLS certificate management with Let's Encrypt
- **Kyverno** - Policy enforcement and governance

### 📊 Monitoring & Observability
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and management
- **Kube-State-Metrics** - Kubernetes object metrics

### 🌐 Networking & Ingress
- **Ingress-NGINX** - HTTP/HTTPS traffic routing
- **MetalLB** - Bare-metal load balancer

### 💾 Storage
- **NFS** - Persistent storage backend
- **Static PV Provisioning** - Predictable storage allocation

### 🛡️ Policy Enforcement (Kyverno)
- Disallow root user containers
- Enforce resource limits
- Trusted container registry validation
- Automated namespace labeling
- ConfigMap generation for new namespaces

## 📋 Prerequisites

- **Kubernetes Cluster**: v1.28+ (tested on k3s)
- **Helm**: v3.14+
- **Helmfile**: Latest version
- **kubectl**: Matching cluster version
- **NFS Server**: For persistent storage
- **Cloudflare Account**: For DNS-01 challenge (cert-manager)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/k8s-cluster.git
cd k8s-cluster
```

### 2. Configure Your Environment

Update the following files with your specific values:

```bash
# Update NFS server address
vim manifests/persistent-volume.yaml

# Update domain and email
vim manifests/cert-manager/cert-manager-clusterissuer.yaml

# Update domain in Ingress configurations
vim values/kube-prometheus/values.yaml
```

### 3. Deploy the Cluster

```bash
# Full deployment
make deploy

# Or step-by-step:
make pre           # Install MetalLB
make namespace     # Create namespaces
make pvs           # Create PersistentVolumes
make secrets       # Configure External Secrets
make helm          # Deploy Helm releases
make cert-manager  # Configure cert-manager
make kyverno       # Apply Kyverno policies
```

### 4. Initialize and Unseal Vault

```bash
# Initialize Vault (first time only)
kubectl exec -n vault vault-0 -- vault operator init

# Save the unseal keys and root token securely!

# Unseal Vault (required after each restart)
make unseal-vault
# Then run the commands with your unseal keys
```

### 5. Configure Vault Secrets

```bash
# Login to Vault
kubectl exec -n vault vault-0 -- vault login <root-token>

# Create Grafana credentials
kubectl exec -n vault vault-0 -- vault kv put kubernetes/grafana-admin-credentials \
  admin-user=admin \
  admin-password=<your-secure-password>

# Create Cloudflare API token
kubectl exec -n vault vault-0 -- vault kv put kubernetes/cloudflare-api-token \
  api-token=<your-cloudflare-token>
```

### 6. Verify Deployment

```bash
# Check cluster status
make status

# Check all pods
kubectl get pods -A

# Check certificates
kubectl get certificates -A

# Check External Secrets
kubectl get externalsecrets -A
```

## 📁 Project Structure

```
.
├── helmfile.yaml                    # Helm releases definition
├── Makefile                         # Automation scripts
├── manifests/                       # Kubernetes manifests
│   ├── cert-manager/               # Cert-manager ClusterIssuers
│   ├── external-secrets/           # ClusterSecretStore configuration
│   ├── kyverno/                    # Kyverno policies
│   ├── metallb/                    # MetalLB IP pool
│   ├── external-secret.yaml        # ExternalSecret resources
│   ├── namespace.yaml              # Namespace definitions
│   ├── persistent-volume.yaml      # Static PVs
│   └── storageclass.yaml           # StorageClass definition
└── values/                          # Helm values
    ├── cert-manager/
    ├── external-secrets/
    ├── ingress-nginx/
    ├── kube-prometheus/
    ├── kyverno/
    ├── metrics-server/
    └── vault/
```

## 🔧 Makefile Commands

| Command | Description |
|---------|-------------|
| `make help` | Display all available commands |
| `make deploy` | Full cluster deployment |
| `make status` | Check cluster status |
| `make validate` | Validate Kubernetes manifests |
| `make unseal-vault` | Display Vault unseal instructions |
| `make clean` | Clean up all resources (⚠️ DANGEROUS) |
| `make pre` | Install MetalLB |
| `make namespace` | Create namespaces |
| `make pvs` | Create PersistentVolumes |
| `make secrets` | Apply External Secrets |
| `make helm` | Deploy Helm releases |

## 🌍 Accessing Services

After deployment, services are accessible via Ingress:

- **Grafana**: https://grafana.yourdomain.com
- **Prometheus**: https://prometheus.yourdomain.com
- **Alertmanager**: https://alertmanager.yourdomain.com
- **Vault**: https://vault.yourdomain.com

Default Grafana credentials are stored in Vault at `kubernetes/grafana-admin-credentials`.

## 🔐 Security Considerations

### Secrets Management
- ✅ All secrets are managed via HashiCorp Vault
- ✅ External Secrets Operator automatically syncs secrets to Kubernetes
- ✅ No hardcoded credentials in Git
- ✅ Vault unseal keys should be stored securely (consider a password manager)

### Network Security
- ✅ All Ingress traffic enforces HTTPS
- ✅ TLS certificates automatically managed by cert-manager
- ✅ Kyverno policies enforce security best practices

### Best Practices Applied
- ✅ Non-root containers (enforced by Kyverno)
- ✅ Resource limits on all pods
- ✅ Trusted container registries only
- ✅ Immutable infrastructure approach
- ✅ GitOps-ready configuration

## 🛠️ Customization

### Adding New Services

1. Add Helm repository to `helmfile.yaml`:
```yaml
repositories:
  - name: my-repo
    url: https://charts.example.com
```

2. Add release configuration:
```yaml
releases:
  - name: my-service
    namespace: my-namespace
    chart: my-repo/my-chart
    values:
      - values/my-service/values.yaml
```

3. Create values file:
```bash
mkdir -p values/my-service
vim values/my-service/values.yaml
```

4. Deploy:
```bash
make helm
```

### Adding Secrets

1. Store secret in Vault:
```bash
kubectl exec -n vault vault-0 -- vault kv put kubernetes/my-secret \
  key=value
```

2. Create ExternalSecret:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-external-secret
  namespace: my-namespace
spec:
  refreshInterval: 10s
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-secret
  data:
  - secretKey: key
    remoteRef:
      key: kubernetes/my-secret
      property: key
```

## 🐛 Troubleshooting

### Vault is Sealed

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Unseal with keys
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>
```

### Certificates Not Issued

```bash
# Check certificate status
kubectl get certificates -A

# Check challenges
kubectl get challenges -A

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### External Secrets Not Syncing

```bash
# Check ClusterSecretStore
kubectl get clustersecretstore vault-backend

# Check ExternalSecrets
kubectl get externalsecrets -A

# Check External Secrets operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### PVs Not Binding

```bash
# Check PV status
kubectl get pv

# Check PVC status
kubectl get pvc -A

# Clean up released PVs
make cleanup-pvs
```

## 📚 Documentation

- [Vault Setup Guide](docs/vault-setup.md)
- [Adding New Services](docs/adding-services.md)
- [Backup and Restore](docs/backup-restore.md)
- [Monitoring Guide](docs/monitoring.md)

## 🤝 Acknowledgments

This project leverages the following amazing open-source projects:

- [Kubernetes](https://kubernetes.io/)
- [Helm](https://helm.sh/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [External Secrets Operator](https://external-secrets.io/)
- [Cert-Manager](https://cert-manager.io/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [Kyverno](https://kyverno.io/)
- [MetalLB](https://metallb.universe.tf/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is a homelab configuration meant for learning and personal use. While security best practices are implemented, this setup should be reviewed and hardened before use in production environments.

---

**Built with ❤️ for the Homelab Community**
