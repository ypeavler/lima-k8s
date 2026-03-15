# This Makefile automates the process of creating and managing Lima VMs

.PHONY: clean-lima-vms create-lima-vms create-single-cp-cluster help

help:
	@echo "Available targets:"
	@echo "  create-lima-vms          - Create HA cluster (3 CP + 2 workers)"
	@echo "  create-single-cp-cluster - Create single CP cluster (1 CP + 2 workers)"
	@echo "  clean-lima-vms           - Clean up all Lima VMs"
	@echo "  help                     - Show this help message"

clean-lima-vms:
	@for vm in $$(limactl list --format '{{.Name}}'); do \
		echo "Stopping VM: $$vm"; \
		limactl stop $$vm; \
		echo "Deleting VM: $$vm"; \
		limactl delete $$vm; \
	done

create-lima-vms:
	@echo "Creating HA cluster (3 control plane + 2 worker nodes)..."
	@for name in cp1 cp2 cp3 wk1 wk2; do \
		echo "Starting VM: $$name"; \
		limactl start --tty=false --name $$name ./lima-template/k8s.yaml ; \
	done
	@echo "Waiting for VMs to be ready..."
	@echo "Listing VM names and IP addresses:"
	@for vm in $$(limactl list --format '{{.Name}}'); do \
		ip=$$(limactl shell $$vm hostname -I | awk '{print $$1}'); \
		echo "VM: $$vm, IP: $$ip"; \
	done

create-single-cp-cluster:
	@echo "Creating single control plane cluster (1 CP + 2 worker nodes)..."
	@for name in k8s-control-plane k8s-worker1 k8s-worker2; do \
		echo "Starting VM: $$name"; \
		limactl start --tty=false --name $$name --network=lima:user-v2 ./lima-template/k8s.yaml ; \
	done
	@echo "Waiting for VMs to be ready..."
	@echo "Listing VM names and IP addresses:"
	@for vm in $$(limactl list --format '{{.Name}}'); do \
		ip=$$(limactl shell $$vm hostname -I | awk '{print $$1}'); \
		echo "VM: $$vm, IP: $$ip"; \
	done
	@echo ""
	@echo "Next steps:"
	@echo "1. limactl shell k8s-control-plane"
	@echo "3. sudo ./shell/2-install-deps.sh"
	@echo "4. sudo ./shell/3-cluster-init.sh"
	@echo "5. sudo ./shell/4-cilium.sh"
	@echo "6. sudo ./shell/5-monitoring.sh"