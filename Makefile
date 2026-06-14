# This Makefile automates the process of creating and managing Lima VMs

.PHONY: clean-lima-vms create-lima-vms create-single-cp-cluster install-dependencies init-control-plane join-worker-nodes copy-kubeconfig install-cilium install-monitoring help

CONTROL_PLANE_VM := k8s-control-plane
SINGLE_CP_VMS := k8s-control-plane k8s-worker1 k8s-worker2
HA_VMS := cp1 cp2 cp3 wk1 wk2
KUBECONFIG_DEST ?= $(HOME)/.kube/config.k8s-on-macos
export LIMA_MOUNT_DIR ?= $(CURDIR)

help: ## Show available targets
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

clean-lima-vms: ## Clean up all Lima VMs
	@for vm in $$(limactl list --format '{{.Name}}'); do \
		echo "Stopping VM: $$vm"; \
		limactl stop $$vm; \
		echo "Deleting VM: $$vm"; \
		limactl delete $$vm; \
	done

create-lima-vms: ## Create HA cluster (3 CP + 2 workers)
	@echo "Creating HA cluster (3 control plane + 2 worker nodes)..."
	@for name in $(HA_VMS); do \
		echo "Starting VM: $$name"; \
		limactl start --tty=false --name $$name ./k8s.yaml ; \
	done
	@echo "Waiting for VMs to be ready..."
	@echo "Listing VM names and IP addresses:"
	@for vm in $(HA_VMS); do \
		ip=$$(limactl shell $$vm hostname -I | awk '{print $$1}'); \
		echo "VM: $$vm, IP: $$ip"; \
	done

create-single-cp-cluster: ## Create single CP cluster (1 CP + 2 workers)
	@echo "Creating single control plane cluster (1 CP + 2 worker nodes)..."
	@for name in $(SINGLE_CP_VMS); do \
		echo "Starting VM: $$name"; \
		limactl start --tty=false --name $$name --network=lima:user-v2 ./k8s.yaml ; \
	done
	@echo "Waiting for VMs to be ready..."
	@echo "Listing VM names and IP addresses:"
	@for vm in $(SINGLE_CP_VMS); do \
		ip=$$(limactl shell $$vm hostname -I | awk '{print $$1}'); \
		echo "VM: $$vm, IP: $$ip"; \
	done
	@echo ""
	@echo "Next steps:"
	@echo "1. make install-dependencies"
	@echo "2. make init-control-plane"
	@echo "3. make join-worker-nodes"
	@echo "4. make install-cilium"
	@echo "5. make install-monitoring"
	@echo "6. make copy-kubeconfig"

install-dependencies: ## Install Kubernetes packages in the control-plane VM
	@limactl shell $(CONTROL_PLANE_VM) -- bash -lc 'cd "$(CURDIR)" && sudo bash ./2-install-deps.sh'

init-control-plane: ## Run kubeadm init in the control-plane VM
	@limactl shell $(CONTROL_PLANE_VM) -- bash -lc 'cd "$(CURDIR)" && sudo bash ./3-cluster-init.sh'

join-worker-nodes: ## Install dependencies on workers and join them to the cluster
	@bash ./3b-join-worker-nodes.sh

copy-kubeconfig: ## Copy kubeconfig from the control-plane VM to the host
	@mkdir -p "$(dir $(KUBECONFIG_DEST))"
	@limactl cp $(CONTROL_PLANE_VM):.kube/config "$(KUBECONFIG_DEST)"
	@echo "Kubeconfig copied to $(KUBECONFIG_DEST)"
	@echo "Run: export KUBECONFIG=$(KUBECONFIG_DEST)"

install-cilium: ## Install Cilium from the control-plane VM
	@limactl shell $(CONTROL_PLANE_VM) -- bash -lc 'cd "$(CURDIR)" && sudo bash ./4-cilium.sh'

install-monitoring: ## Install monitoring add-ons from the control-plane VM
	@limactl shell $(CONTROL_PLANE_VM) -- bash -lc 'cd "$(CURDIR)" && sudo bash ./5-monitoring.sh'
