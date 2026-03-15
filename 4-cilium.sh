#!/bin/bash

# Check and install Cilium CLI if not present
if ! command -v cilium &> /dev/null; then
  echo "Cilium CLI not found. Installing..."
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  CLI_ARCH=arm64
  cd /tmp
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
  rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
else
  echo "Cilium CLI is already installed."
fi

# Check and install Helm if not present
if ! command -v helm &> /dev/null; then
  echo "Helm not found. Installing..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  rm get_helm.sh
else
  echo "Helm is already installed."
fi

# Install Cilium using Helm
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.17.3 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set hostServices.enabled=true \
  --set serviceAccount.enabled=true \
  --set k8sServiceHost=192.168.104.200 \
  --set k8sServicePort=6443 \
  --set ipam.mode=cluster-pool \
  --set ipam.clusterPoolIPv4PodCIDR=10.254.0.0/16 \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set hubble.enabled=true \
  --set hubble.metrics.enableOpenMetrics=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}"

cilium status --wait