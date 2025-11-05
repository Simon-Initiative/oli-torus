#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "usage: $0 <namespace>" >&2
  exit 1
fi

NAMESPACE="$1"
export PR_NAMESPACE="$NAMESPACE"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

for manifest in devops/k8s/policies/resource-quota.yaml \
                 devops/k8s/policies/network-policy.yaml; do
  envsubst < "$manifest" | kubectl -n "$NAMESPACE" apply -f -
done
