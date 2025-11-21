.PHONY: help init plan apply destroy clean validate format

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate

format: ## Format Terraform files
	terraform fmt -recursive

plan: ## Plan Terraform deployment
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all Terraform resources
	terraform destroy

clean: ## Clean Terraform files
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate
	rm -f terraform.tfstate.backup
	rm -f tfplan

get-credentials: ## Get AKS credentials (requires cluster to be deployed)
	@bash -c 'RG=$$(terraform output -raw resource_group_name); CLUSTER=$$(terraform output -raw cluster_name); az aks get-credentials --resource-group $$RG --name $$CLUSTER --overwrite-existing'

check-gpu: ## Check GPU nodes status
	kubectl get nodes -l gpu-enabled=true -o wide

show-outputs: ## Show Terraform outputs
	terraform output
