# DevOps Operations Reference

This directory contains the infrastructure assets that support the k3s-based preview environments described in `devops/plan.md` and `devops/k8s_migration_plan.md`.

## Structure

- `plan.md` – implementation plan and phase breakdown.
- `k8s/` – Kubernetes manifests applied cluster-wide (RBAC, policies, namespace templates). Files using `{{PR_NAMESPACE}}` require substitution before applying (e.g., `env PR_NAMESPACE=pr-123 envsubst < ...`). Requires GNU `envsubst` (gettext). Adjust egress ports in `policies/network-policy.yaml` to match downstream services (DB, caches, HTTP).
- `helm/` – Helm charts used to deploy preview environments.
- `scripts/` – Helper scripts consumed by CI and operators.
- `change-log.md` – Record of operational changes and procedures.
- `default.env` – Baseline application environment used to seed the Helm chart secret (`appEnv` values) for preview deployments.

### Scripts

- `devops/scripts/apply-preview-policies.sh` – Creates/updates a PR namespace and applies quota, limit range, and network policy manifests (requires `PR_NAMESPACE` argument).
- `devops/scripts/smoke-test-preview.sh` – Simple curl-based probe runner for verifying preview endpoints locally or in CI.

## k3s Installation Checklist

Perform these steps on each Amazon Linux 2023 host before joining it to the cluster:

1. Apply updates and enable automatic patching:
   ```bash
   sudo dnf update -y
   sudo systemctl enable --now dnf-automatic.timer
   ```
2. Enforce SSH hardening (key-based auth only) and confirm `sshd` restarts cleanly.
3. Configure firewall rules for inbound `tcp/22`, `tcp/80`, `tcp/443`, and NodePort range `30000-32767` from HAProxy.
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
7. Install Helm (latest 3.x) so the runner can execute `helm` commands:
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   helm version
   ```
8. Record the node token from `/var/lib/rancher/k3s/server/node-token` for future worker joins.

Keep this checklist updated as installation practices evolve.
