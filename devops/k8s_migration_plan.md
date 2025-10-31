# Preview Environments on k3s — Technical Approach & Migration Plan

**Audience:** infra/dev owner (solo today), app engineers.\
**Current state:** Single host running Docker Compose + Traefik, deployed via GitHub Actions on PR events.\
**Target state:** Single‑node **k3s** cluster (control‑plane + workload on 1 machine) with the ability to add worker nodes later. Per‑PR ephemeral environments delivered via Kustomize overlays, Traefik Ingress, and GitHub Actions (with optional cert-manager when cluster-managed TLS is desired).

---

## 1) Goals & Non‑Goals

**Goals**

- Keep single‑operator simplicity; minimal moving parts.
- Per‑PR environments: unique hostnames, easy env/secrets, auto‑update on push, auto‑teardown on PR close.
- Resource isolation and caps to avoid noisy neighbors.
- Smooth migration (zero/low downtime to preview URLs).
- Future‑proof for multi‑node scaling without redesign.

**Non‑Goals (for now)**

- Autoscaling *within* each preview (we’ll run 1 replica per component).
- Full GitOps platform (ArgoCD/Flux) — optional later.
- HA control plane — single server today; later add workers and (optionally) convert to multi‑server + etcd.

---

## 2) High‑Level Architecture

- **Edge:** **system HAProxy** terminates TLS for `*.plasma.oli.cmu.edu` and routes based on SNI/Host. Non‑matching routes fall through to **Traefik**.
- **Ingress inside cluster:** **Traefik** (bundled with k3s) handles Kubernetes **Ingress** resources and routes to Services/Pods.
- **Connectivity HAProxy → Traefik:** HAProxy forwards **plain HTTP** to Traefik’s **NodePort** service on the k3s node (single node today; add workers later without changing HAProxy).
- **DNS/TLS:** You already manage wildcard DNS and certs at HAProxy; **no cert-manager is required**. Ingress objects can be HTTP‑only.
- **Per‑PR delivery:** **Kustomize** base + overlay per PR (`pr-<n>`) in namespace `pr-<n>`, exposed by Ingress host `pr-<n>.plasma.oli.cmu.edu`.
- **CI runner:** GitHub Actions uses the self‑hosted runner `` on the k3s node; workflows run `kubectl`/`helm` **locally** (no SSH).
- **Storage:** k3s **local-path-provisioner** now; plan for **Longhorn/CSI** when adding workers.

### 2.1 Edge Routing Topology (HAProxy in front)

```
Internet → HAProxy (TLS terminate, SNI/Host routing) → Traefik NodePort (HTTP) → Ingress → Service → Pod
```

**Example HAProxy sketch** (adjust names/ports):

```haproxy
frontend https-in
  bind :443 ssl crt /etc/ssl/private/wildcard-plasma.pem
  mode http
  # Route some other services first
  acl is_grafana hdr(host) -i grafana.plasma.oli.cmu.edu
  use_backend grafana if is_grafana

  # Fallthrough to Traefik for preview hosts *.plasma.oli.cmu.edu
  default_backend traefik

backend traefik
  mode http
  option httpchk GET /
  # Traefik Service is NodePort; discover via `kubectl -n kube-system get svc traefik -o yaml`
  # Assume NodePort 30080 for HTTP (example)
  server k3snode 127.0.0.1:30080 check
```

> In k3s, Traefik runs as a Service (type **LoadBalancer** or **NodePort**). Set it to **NodePort** and point HAProxy at `nodeIP:nodePort`. When you add workers, you can point HAProxy at multiple nodeIPs for fan‑out (or keep only the control‑plane if Traefik runs only there).

---

## 3) Cluster Setup (Single Node Now, Expandable Later)

### 3.1 Install k3s (server)

- OS hardening: ufw/firewalld rules, disable password SSH, enable unattended upgrades.
- Install k3s (server):
  ```bash
  curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable=servicelb  # we’ll rely on Traefik + host/NLB
  ```
- Confirm: `kubectl get nodes`, `kubectl get pods -A` (Traefik should be running in `kube-system`).

> **Note:** When you later add **workers**, retrieve the node token from `/var/lib/rancher/k3s/server/node-token` and join workers with:\
> `curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<token> sh -`.

### 3.2 Ingress & TLS

- Keep bundled **Traefik** for Ingress.
- (Optional) Install **cert-manager** (e.g., via Helm) + a ClusterIssuer for your DNS provider (DNS‑01 challenge):
  ```bash
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set installCRDs=true
  ```
- Create a `ClusterIssuer` (example for Cloudflare):
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-dns
  spec:
    acme:
      email: ops@example.com
      server: https://acme-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: acme-account-key
      solvers:
      - dns01:
          cloudflare:
            email: ops@example.com
            apiTokenSecretRef:
              name: cloudflare-dns-token
              key: api-token
  ```

### 3.3 DNS

- **Simplest**: wildcard DNS `*.preview.example.com` → public IP of the node (or LB).
- **Optional**: **ExternalDNS** to manage per‑PR records automatically if you prefer unique A/AAAA per preview.

### 3.4 Container Registry

- Use **GHCR** (current) or another registry. Configure imagePullSecrets at namespace or serviceaccount level.

---

## 4) Namespaces, Isolation & Baseline Policies

Create a per‑PR namespace with guardrails:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: pr-123
  labels:
    env: preview
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: rq
  namespace: pr-123
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "10"
    services: "5"
    requests.storage: 10Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limits
  namespace: pr-123
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: 512Mi
    defaultRequest:
      cpu: "100m"
      memory: 256Mi
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: pr-123
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Allow ingress only via the app’s Service/Ingress (Traefik will target the Service’s endpoints):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-traefik
  namespace: pr-123
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: TCP
      port: 3000  # your app containerPort
```

> Adjust ports/selectors as needed; or use Traefik’s ServiceAccount/Pod labels for a tighter policy.

---

## 5) Kustomize Base & Preview Overlays

- Store cluster-wide manifests (RBAC, quotas, policies) under `devops/k8s/`.
- Store namespace-scoped resources under `devops/kustomize/`:
  - `base/` defines the canonical Deployment, Postgres/MinIO StatefulSets, Jobs, Ingresses, middlewares, and the shared secret generator sourced from `devops/default.env`.
  - `overlays/preview/` overlays per-preview values (namespace slug, host, image tag, secret overrides, image pull secrets). The deploy workflow renders this overlay for each PR or manual deploy.

Minimal preview overlay (`devops/kustomize/overlays/preview/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

configMapGenerator:
  - name: preview-params
    envs:
      - params.env  # contains PREVIEW_SLUG + PREVIEW_DOMAIN
    behavior: merge

secretGenerator:
  - name: app-env
    behavior: merge
    envs:
      - app-overrides.env  # concrete HOST/MEDIA_URL overrides per preview

vars:
  - name: PREVIEW_SLUG
    objref:
      kind: ConfigMap
      name: preview-params
      apiVersion: v1
    fieldref:
      fieldpath: data.PREVIEW_SLUG
  - name: PREVIEW_DOMAIN
    objref:
      kind: ConfigMap
      name: preview-params
      apiVersion: v1
    fieldref:
      fieldpath: data.PREVIEW_DOMAIN

patches:
  - path: patches/app-ingress.yaml
  - path: patches/ingress-minio-api.yaml
  - path: patches/ingress-minio-console.yaml
  - path: patches/app-deployment.yaml
  - path: patches/minio-statefulset.yaml
```

`params.env` supplies the namespace slug and domain (e.g., `PREVIEW_SLUG=pr-123`). `app-overrides.env` overrides a subset of env vars (HOST, MEDIA_URL, etc.). The workflow rewrites both files before running `kustomize build`.

To render locally:

```bash
export PREVIEW_SLUG=pr-123
export PREVIEW_DOMAIN=plasma.oli.cmu.edu
cat <<EOF > devops/kustomize/overlays/preview/params.env
PREVIEW_SLUG=$PREVIEW_SLUG
PREVIEW_DOMAIN=$PREVIEW_DOMAIN
EOF
cat <<EOF > devops/kustomize/overlays/preview/app-overrides.env
HOST=${PREVIEW_SLUG}.${PREVIEW_DOMAIN}
MEDIA_URL=https://${PREVIEW_SLUG}.${PREVIEW_DOMAIN}/buckets/torus-media
EOF
kustomize build --load-restrictor LoadRestrictionsNone devops/kustomize/overlays/preview | kubectl apply -f -
```

When the namespace is deleted, PVCs for Postgres/MinIO are deleted too. As long as you redeploy with the same slug, data persists across `kubectl apply` runs.

---

## 6) CI/CD — GitHub Actions Workflows

### 6.1 Prereqs (runner on `plasma`)

- Use the **self-hosted runner** labels: `runs-on: plasma` (or `[self-hosted, plasma]`).
- Provide the runner user read access to `/etc/rancher/k3s/k3s.yaml`.
- Ensure Docker, `kubectl`, and `kustomize` are installed (workflows use `imranismail/setup-kustomize`).
- Store `SIMON_BOT_PERSONAL_ACCESS_TOKEN` (PAT with `read:packages`) for GHCR pulls; the workflow recreates a `ghcr-creds` secret per namespace.

### 6.2 Deploy/Update

- Triggered on PR open/sync and via `workflow_dispatch`.
- Steps:
  1. Checkout the requested ref.
  2. Build & push the PR image to GHCR (`ghcr.io/...:sha-<commit>`).
  3. Apply baseline namespace policies via `devops/scripts/apply-preview-policies.sh`.
  4. Create/refresh the `ghcr-creds` secret in the namespace.
  5. Rewrite `params.env` and `app-overrides.env` with the slug/domain.
  6. `kustomize build … | kubectl apply -f -` to reconcile workloads.
  7. Wait for the app deployment to roll out.
  8. Post (or refresh) a sticky PR comment with the preview URL (only on PR events).

Manual dispatch accepts a `ref` (branch/tag) and `preview_id` (slug) so you can deploy arbitrary branches without opening a PR.

### 6.3 Cleanup

- Triggered on PR close or manual dispatch with a `preview_id`.
- Deletes the namespace (and removes the sticky comment only for PR-triggered runs).
- PVCs are namespace-scoped, so deleting the namespace is the authoritative cleanup mechanism.

---

### 6.4 Additional Considerations

- Keep kubeconfig access limited (consider a dedicated ServiceAccount scoped to `pr-*`).
- If you adopt cert-manager later, add a `ClusterIssuer` and annotate ingresses accordingly; the Kustomize overlays can template TLS blocks when needed.
- HAProxy must continue pointing its default backend at Traefik’s NodePort so newly created hosts start routing immediately.
