#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONTROL_PLANE_VM="${CONTROL_PLANE_VM:-k8s-control-plane}"
if [[ "$#" -gt 0 ]]; then
  WORKER_VMS=("$@")
else
  WORKER_VMS=(k8s-worker1 k8s-worker2)
fi

require_running_vm() {
  local vm="$1"
  if ! limactl list "${vm}" >/dev/null 2>&1; then
    echo "Lima VM not found: ${vm}" >&2
    return 1
  fi

  local status
  status=$(limactl list "${vm}" --format '{{.Status}}')
  if [[ "${status}" != "Running" ]]; then
    echo "Lima VM is not running: ${vm} (${status})" >&2
    return 1
  fi
}

require_running_vm "${CONTROL_PLANE_VM}"
for worker in "${WORKER_VMS[@]}"; do
  require_running_vm "${worker}"
done

api_endpoint=$(limactl shell "${CONTROL_PLANE_VM}" -- bash -lc '
  if [[ -f /tmp/lima/kubeadm-config.yaml ]]; then
    endpoint=$(awk "/controlPlaneEndpoint:/ {print \$2}" /tmp/lima/kubeadm-config.yaml | tail -n 1)
    if [[ -n "${endpoint}" ]]; then
      printf "%s" "${endpoint}"
      exit 0
    fi
  fi
  printf "%s:6443" "$(hostname -I | awk "{print \$1}")"
')

token=$(limactl shell "${CONTROL_PLANE_VM}" -- sudo kubeadm token create)
ca_cert_hash=$(limactl shell "${CONTROL_PLANE_VM}" -- bash -lc '
  sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
    | sudo openssl rsa -pubin -outform DER 2>/dev/null \
    | openssl dgst -sha256 -hex \
    | sed "s/^.* //"
')

join_args=(
  kubeadm join
  "${api_endpoint}"
  --token
  "${token}"
  --discovery-token-ca-cert-hash
  "sha256:${ca_cert_hash}"
  --cri-socket=unix:///run/containerd/containerd.sock
)

for worker in "${WORKER_VMS[@]}"; do
  echo "Preparing ${worker}..."
  limactl shell "${worker}" -- bash -lc "cd '${SCRIPT_DIR}' && sudo bash ./2-install-deps.sh"

  if limactl shell "${worker}" -- test -f /etc/kubernetes/kubelet.conf; then
    echo "${worker} is already joined."
    continue
  fi

  echo "Joining ${worker} to the cluster..."
  limactl shell "${worker}" -- sudo "${join_args[@]}"
done

echo "Current cluster nodes:"
limactl shell "${CONTROL_PLANE_VM}" -- sudo env KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
