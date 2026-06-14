# lima-k8s

Local Kubernetes lab automation for Lima on macOS.

## What this repo contains

Step 1 of the workflow is VM creation with `make create-single-cp-cluster` or
`make create-lima-vms`. That is why the numbered scripts begin at `2-` rather
than `1-`.

- `k8s.yaml` - Lima VM template
- `2-install-deps.sh` - guest package installation and CRI setup
- `3-cluster-init.sh` - single control-plane kubeadm bootstrap
- `3a-ha-cluster-init.sh` - HA control-plane bootstrap
- `3b-join-worker-nodes.sh` - worker dependency install and join flow
- `4-cilium.sh` - Cilium install
- `5-monitoring.sh` - monitoring add-ons
- `Makefile` - primary host-side interface for creation, bootstrap, and cleanup

## Decisions and rationale

This repo keeps the automation focused on reproducible cluster setup.
Broader rationale, design choices, and workflow explanations live in the
companion blog post:

- `Kubernetes Lab with kubeadm and Lima on macOS`

That post explains decisions such as:

- why Lima VMs are used instead of a single-node local distro
- why VM provisioning is separate from package installation
- why `kube-proxy` is disabled
- how the worker join flow fits into the full cluster bootstrap
- why Cilium endpoint selection differs between single control-plane and HA flows

## Typical flow

Step 1 is VM creation from the host. The numbered scripts begin after that
point. The supported day-to-day interface is the host-side `Makefile`; the
numbered shell scripts are guest-side implementation helpers.

```bash
make create-single-cp-cluster
make init-control-plane
make join-worker-nodes
make install-cilium
make install-monitoring
make copy-kubeconfig
export KUBECONFIG=~/.kube/config.k8s-on-macos
kubectl get nodes -o wide
```
