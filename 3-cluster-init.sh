#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eux -o pipefail

# Check if the cluster is already initialized
if test -e /etc/kubernetes/admin.conf; then
    echo "Kubernetes cluster is already initialized. Exiting."
    exit 0
fi

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/kubernetes/admin.conf

# Stop kubelet service before pulling images
systemctl stop kubelet

# List and pull required Kubernetes images
kubeadm config images list
kubeadm config images pull --cri-socket=unix:///run/containerd/containerd.sock

# Start kubelet service
systemctl start kubelet

# Create kubeadm configuration file
cat <<EOF >/tmp/lima/kubeadm-config.yaml
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
skipPhases:
  - addon/kube-proxy
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
apiServer:
  certSANs: # --apiserver-cert-extra-sans
  - "127.0.0.1"
proxy:
  disabled: true
networking:
  podSubnet: "10.254.0.0/16" # --pod-network-cidr
  serviceSubnet: "10.255.0.0/16" # --service-cidr
clusterName: "lima-vm-cluster"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

# Initialize the Kubernetes control-plane node
kubeadm init --config /tmp/lima/kubeadm-config.yaml --upload-certs

# Remove control-plane node isolation
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Replace the server address with localhost for host access
sed -e "/server:/ s|https://.*:\([0-9]*\)$|https://127.0.0.1:\1|" -i $KUBECONFIG

# Copy kubeconfig to the user's home directory for kubectl access
mkdir -p ${HOME:-/root}/.kube
cp -f $KUBECONFIG ${HOME:-/root}/.kube/config

echo "Kubernetes control-plane node initialized successfully."
