# DevOps Operations Reference

This directory contains the infrastructure assets that support the k3s-based preview environments.

## Structure

- `k8s/` – Kubernetes manifests applied cluster-wide (RBAC, policies, namespace templates). Files using `${PR_NAMESPACE}` require substitution before applying (e.g., `env PR_NAMESPACE=pr-123 envsubst < ...`). Requires GNU `envsubst` (gettext). Adjust egress ports in `policies/network-policy.yaml` to match downstream services (DB, caches, HTTP).
- `kustomize/` – Base manifests and overlays used to render per-preview (per namespace) resources.
- `scripts/` – Helper scripts consumed by CI and operators.
- `default.env` – Baseline application environment consumed by the Kustomize secret generator for preview deployments.

### Scripts

- `devops/scripts/apply-preview-policies.sh` – Creates/updates a PR namespace and applies quota and network policy manifests (requires `PR_NAMESPACE` argument).
- `devops/scripts/smoke-test-preview.sh` – Simple curl-based probe runner for verifying preview endpoints locally or in CI.

### Manually updating preview environment config

Use these steps to adjust application environment variables for an existing preview deployment when you have shell access to the cluster host:

1. Ensure the repository (and this directory) is present on the host so you can reuse the baseline files in `devops/`.
2. Set helpers for the namespace and domain you are updating (replace the slug/domain with your target):
   ```bash
   export PREVIEW_SLUG=pr-123
   export PREVIEW_DOMAIN=plasma.oli.cmu.edu
   export PREVIEW_HOST="${PREVIEW_SLUG}.${PREVIEW_DOMAIN}"
   ```
3. Build a complete environment file. Start from the default template so required keys exist, then append overrides:
   ```bash
   cd /path/to/oli-torus
   HOST="${PREVIEW_HOST}" envsubst < devops/default.env > /tmp/app.env
   cat <<'EOF' >> /tmp/app.env
   MY_FEATURE_FLAG=true
   OTHER_SECRET=value
   EOF
   ```
4. Apply the updated secret in place; name stability is required because the kustomize generator disables suffix hashes:
   ```bash
   kubectl create secret generic app-env \
     --from-env-file=/tmp/app.env \
     --dry-run=client -o yaml \
   | kubectl -n "${PREVIEW_SLUG}" apply -f -
   ```
5. Restart the application deployment and wait for rollout completion so pods pick up the new environment:
   ```bash
   kubectl -n "${PREVIEW_SLUG}" rollout restart deployment/app
   kubectl -n "${PREVIEW_SLUG}" rollout status deployment/app --timeout=5m
   ```
6. Optionally run `devops/scripts/smoke-test-preview.sh "https://${PREVIEW_HOST}"` (or your own checks) to verify behaviour after the update.

## k3s Installation Checklist

Perform these steps on each Amazon Linux 2023 host before joining it to the cluster:

1. Apply updates and enable automatic patching:
   ```bash
   sudo dnf update -y
   sudo systemctl enable --now dnf-automatic.timer
   ```
2. Enforce SSH hardening (key-based auth only) and confirm `sshd` restarts cleanly.
3. Configure firewall rules for inbound `tcp/22`, `tcp/80`, `tcp/443`, and the Traefik NodePorts (`tcp/30080`, `tcp/31505` by default) from HAProxy. Trust the k3s pod network interfaces so in-cluster routes work:
   ```bash
   sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
   sudo firewall-cmd --zone=trusted --add-interface=flannel.1 --permanent
   sudo firewall-cmd --zone=trusted --add-source=10.42.0.0/16 --permanent
   sudo firewall-cmd --zone=trusted --add-port=30080/tcp --permanent
   sudo firewall-cmd --zone=trusted --add-port=31505/tcp --permanent
   sudo firewall-cmd --reload
   ```
4. Install k3s:
   ```bash
   curl -sfL https://get.k3s.io | sh -s - \
     --write-kubeconfig-mode 644 \
     --disable=servicelb
   sudo systemctl enable --now k3s
   ```
5. Validate cluster health:
   ```bash
   sudo kubectl get nodes
   sudo kubectl get pods -A
   ```
6. Provide the self-hosted runner user read access to `/etc/rancher/k3s/k3s.yaml`:
   ```bash
   sudo install -m 600 -o runner -g runner \
     /etc/rancher/k3s/k3s.yaml /home/runner/.kube/config
   ```
7. Install the Kustomize CLI (or ensure `kubectl kustomize` is available):
   ```bash
   curl -sS https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
   sudo mv kustomize /usr/local/bin/
   kustomize version
   ```
8. Record the node token from `/var/lib/rancher/k3s/server/node-token` for future worker joins.

Keep this checklist updated as installation practices evolve.
