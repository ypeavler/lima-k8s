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

# create vip
cat <<EOF >/etc/kubernetes/manifests/kube-vip.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - args:
    - manager
    env:
    - name: vip_arp
      value: "true"
    - name: port
      value: "6443"
    - name: vip_nodename
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: vip_interface
      value: eth0
    - name: vip_subnet
      value: "32"
    - name: dns_mode
      value: first
    - name: cp_enable
      value: "true"
    - name: cp_namespace
      value: kube-system
    - name: svc_enable
      value: "true"
    - name: svc_leasename
      value: plndr-svcs-lock
    - name: vip_leaderelection
      value: "true"
    - name: vip_leasename
      value: plndr-cp-lock
    - name: vip_leaseduration
      value: "5"
    - name: vip_renewdeadline
      value: "3"
    - name: vip_retryperiod
      value: "1"
    - name: address
      value: 192.168.104.200
    - name: prometheus_server
      value: :2112
    image: ghcr.io/kube-vip/kube-vip:v0.9.1
    imagePullPolicy: IfNotPresent
    name: kube-vip
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
        drop:
        - ALL
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kubeconfig
  hostAliases:
  - hostnames:
    - kubernetes
    ip: 127.0.0.1
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/super-admin.conf
    name: kubeconfig
status: {}
EOF
# Create kubeadm configuration file
mkdir -p /tmp/lima
cat <<EOF >/tmp/lima/kubeadm-config.yaml
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
localAPIEndpoint:
  advertiseAddress: 192.168.104.12
  bindPort: 6443
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
  - "192.168.104.200"
proxy:
  disabled: true
networking:
  podSubnet: "10.254.0.0/16" # --pod-network-cidr
  serviceSubnet: "10.255.0.0/16" # --service-cidr
controlPlaneEndpoint: "192.168.104.200:6443" # --control-plane-endpoint
clusterName: "lima-vm-cluster"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

# Initialize the Kubernetes control-plane node
kubeadm init --config /tmp/lima/kubeadm-config.yaml --upload-certs

#https://github.com/kube-vip/kube-vip/issues/684 -- need to use super-admin.conf before init and update it after
sed -i 's#path: /etc/kubernetes/super-admin.conf#path: /etc/kubernetes/admin.conf#' \
          /etc/kubernetes/manifests/kube-vip.yaml

# Remove control-plane node isolation
#kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Copy kubeconfig to the invoking user's home directory for kubectl access
root_home=$(getent passwd root | cut -d: -f6)
mkdir -p "${root_home}/.kube"
cp -f "$KUBECONFIG" "${root_home}/.kube/config"

if [[ -n "${SUDO_USER:-}" ]]; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    mkdir -p "${user_home}/.kube"
    cp -f "$KUBECONFIG" "${user_home}/.kube/config"
    chown -R "$SUDO_USER":"$SUDO_USER" "${user_home}/.kube"
fi

echo "Kubernetes control-plane node initialized successfully."
