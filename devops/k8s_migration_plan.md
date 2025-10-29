# Preview Environments on k3s — Technical Approach & Migration Plan

**Audience:** infra/dev owner (solo today), app engineers.\
**Current state:** Single host running Docker Compose + Traefik, deployed via GitHub Actions on PR events.\
**Target state:** Single‑node **k3s** cluster (control‑plane + workload on 1 machine) with the ability to add worker nodes later. Per‑PR ephemeral environments delivered via Helm, Traefik Ingress, cert‑manager, and GitHub Actions.

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
- **Per‑PR delivery:** **Helm** chart per PR (`pr-<n>`) in namespace `pr-<n>`, exposed by Ingress host `pr-<n>.plasma.oli.cmu.edu`.
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
- Install **cert-manager** (Helm) + ClusterIssuer for your DNS provider (DNS‑01 challenge):
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

## 5) Helm Chart (Per‑PR Release)

- Chart remains the same structure, but **Ingress is HTTP‑only** (no `spec.tls`).
- Host pattern: `pr-<n>.plasma.oli.cmu.edu`.

``** (Traefik, HTTP‑only)**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "app.fullname" . }}
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: {{ .Values.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "app.fullname" . }}
                port:
                  number: 80
```

---

## 5.1 Where to store Helm charts

**Now (recommended):** keep the chart **inside the app repo** at `deploy/helm/app/` so PRs can evolve code + templates together.\
**Later:** publish the chart as an **OCI artifact to GHCR** for reuse/versioning across repos; optionally maintain source in a small **infra repo**.

**Publish to GHCR (example):**

```bash
export HELM_EXPERIMENTAL_OCI=1
helm package deploy/helm/app
helm registry login ghcr.io -u "$GH_USER" -p "$CR_PAT"
helm push app-0.1.0.tgz oci://ghcr.io/your-org/helm
```

**Consume from GHCR:**

```bash
helm registry login ghcr.io -u "$GH_USER" -p "$CR_PAT"
helm upgrade --install pr-$PR oci://ghcr.io/your-org/helm/app \
  --version 0.1.0 \
  --namespace pr-$PR --create-namespace \
  --set image.repository=ghcr.io/your-org/your-app \
  --set image.tag=pr-$PR \
  --set host=pr-$PR.plasma.oli.cmu.edu
```

---

## 6) CI/CD — GitHub Actions Workflows

### 6.1 Prereqs (runner on `plasma`)

- Use the **self‑hosted runner** labels: `runs-on: [self-hosted, plasma]`.
- Use the node’s kubeconfig (`/etc/rancher/k3s/k3s.yaml`) or a readonly copy for the runner user.
- No SSH required; run `kubectl`/`helm` locally in the workflow.

### 6.2 Deploy/Update on PR open/sync

```yaml
name: preview-deploy
on:
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  deploy:
    runs-on: [self-hosted, plasma]
    steps:
      - uses: actions/checkout@v4
      - name: Build & push image
        run: |
          TAG=pr-${{ github.event.number }}
          echo $CR_PAT | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin
          docker build -t ghcr.io/your-org/your-app:$TAG .
          docker push ghcr.io/your-org/your-app:$TAG
      - name: Create namespace & baseline
        env:
          PR: ${{ github.event.number }}
        run: |
          kubectl create ns pr-$PR --dry-run=client -o yaml | kubectl apply -f -
          # (optional) apply ResourceQuota/LimitRange/NetworkPolicy here
      - name: Helm upgrade/install
        env:
          PR: ${{ github.event.number }}
        run: |
          helm upgrade --install pr-$PR deploy/helm/app \
            --namespace pr-$PR --create-namespace \
            --set image.repository=ghcr.io/your-org/your-app \
            --set image.tag=pr-$PR \
            --set host=pr-$PR.plasma.oli.cmu.edu
```

### 6.3 Teardown on PR close

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  teardown:
    runs-on: [self-hosted, plasma]
    steps:
      - name: Uninstall
        env:
          PR: ${{ github.event.number }}
        run: |
          helm uninstall pr-$PR -n pr-$PR || true
          kubectl delete ns pr-$PR --wait=false || true
```

**Note:** ensure HAProxy default backend points at Traefik’s NodePort so newly created Ingress hosts immediately work.

---

### 6.1 Prereqs

- Store kubeconfig on runner via secrets (or use `appleboy/ssh-action` to run `helm` on the node).
- Create a read‑only **ServiceAccount** with limited RBAC (namespace admin for `pr-*`).
- Create a registry **imagePullSecret** named `ghcr-creds` in each PR namespace (or at default + serviceAccount).
- Ensure `cloudflare-dns-token` (or your DNS provider token) exists in `cert-manager` namespace.

### 6.2 Deploy/Update on PR open/sync

```yaml
name: preview-deploy
on:
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build & push image
        run: |
          TAG=pr-${{ github.event.number 
```
