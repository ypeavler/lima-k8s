#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eux -o pipefail 

helm upgrade cilium cilium/cilium --version 1.17.3 \
  --namespace kube-system \
  --reuse-values \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  # enable relay if you have enough resources
  #--set hubble.relay.enabled=false \ 
  --set hubble.enabled=true \
  --set hubble.metrics.enableOpenMetrics=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}"

# install prometheus and grafana
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.17.3/examples/kubernetes/addons/prometheus/monitoring-example.yaml