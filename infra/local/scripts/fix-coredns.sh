#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kube-system"
CONFIGMAP="coredns"
DEPLOYMENT="coredns"
TARGET_FORWARD="forward . 8.8.8.8 8.8.4.4"

TMP_COREFILE="$(mktemp)"
trap 'rm -f "${TMP_COREFILE}"' EXIT

echo "==> Checking kubectl connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach a cluster." >&2
  exit 1
fi

echo "==> Checking namespace ${NAMESPACE} exists..."
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace ${NAMESPACE} not found." >&2
  exit 1
fi

echo "==> Reading current CoreDNS Corefile..."
kubectl get configmap "${CONFIGMAP}" -n "${NAMESPACE}" \
  -o jsonpath='{.data.Corefile}' >"${TMP_COREFILE}"

if grep -qF "${TARGET_FORWARD}" "${TMP_COREFILE}"; then
  echo "==> CoreDNS already forwards to 8.8.8.8 8.8.4.4 — nothing to patch."
else
  echo "==> Patching forward target: /etc/resolv.conf -> 8.8.8.8 8.8.4.4"
  sed -i "s#forward \. /etc/resolv\.conf#${TARGET_FORWARD}#" "${TMP_COREFILE}"
  kubectl create configmap "${CONFIGMAP}" -n "${NAMESPACE}" \
    --from-file=Corefile="${TMP_COREFILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "==> Restarting CoreDNS to pick up the change..."
kubectl rollout restart deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"
kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=90s

echo "==> CoreDNS pods:"
kubectl get pods -n "${NAMESPACE}" -l k8s-app=kube-dns

echo "==> Done. CoreDNS is patched and Running."
