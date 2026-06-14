#!/bin/bash

# Set the Kubernetes version to install
VERSION=1.32.0
export DEBIAN_FRONTEND=noninteractive

# Exit immediately if a command exits with a non-zero status
set -eux -o pipefail

check_tls_access() {
    local url="$1"
    if ! curl -fsSLI --max-time 20 "$url" >/dev/null; then
        cat >&2 <<'EOF'
Unable to reach a required HTTPS endpoint from the guest VM.
If you are on a corporate network, install the required corporate root
certificates into the guest trust store before re-running this script.
EOF
        return 1
    fi
}

# Check if kubeadm is already installed
if command -v kubeadm >/dev/null 2>&1; then
    echo "kubeadm is already installed. Exiting."
    exit 0
fi

check_tls_access "https://dl.k8s.io/release/stable.txt"
check_tls_access "https://pkgs.k8s.io/"

# Load necessary kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Configure sysctl parameters for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Determine the stable Kubernetes version
VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt | sed -e 's/v//' | cut -d'.' -f1-2)

# Add Kubernetes apt repository
mkdir -p /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Update package lists
apt-get update

# Install cri-tools
apt-get install -y cri-tools

# Configure crictl to use containerd
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

# Install CNI plugins
apt-get install -y kubernetes-cni
rm -f /etc/cni/net.d/*.conf*

# Install kubelet, kubeadm, and kubectl, and mark them to prevent updates
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable and start kubelet service
systemctl enable --now kubelet

systemctl restart containerd

echo "Kubernetes dependencies installed successfully."