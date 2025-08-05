# =============================================================================
# MICROSERVICES APPLICATION HELM CHART MAKEFILE
# =============================================================================
# Common operations for managing the Helm chart

.PHONY: help validate lint test install upgrade uninstall clean docs diagrams install-kubediagrams setup-aws-iam setup-kubectl-cost

# Default target
help:
	@echo "=============================================================================="
	@echo "MICROSERVICES APPLICATION HELM CHART"
	@echo "=============================================================================="
	@echo ""
	@echo "Available targets:"
	@echo "  help      - Show this help message"
	@echo "  validate  - Validate the Helm chart"
	@echo "  lint      - Lint the Helm chart"
	@echo "  test      - Test template rendering"
	@echo "  install   - Install the chart (development)"
	@echo "  upgrade   - Upgrade the chart"
	@echo "  uninstall - Uninstall the chart"
	@echo "  clean     - Clean up generated files"
	@echo "  docs      - Generate documentation"
	@echo "  diagrams  - Generate architecture diagrams"
	@echo "  install-kubediagrams - Install KubeDiagrams tool"
	@echo "  setup-aws-iam - Setup AWS IAM Authenticator"
	@echo "  setup-kubectl-cost - Setup kubectl-cost for cost monitoring"
	@echo ""

# Variables
CHART_NAME := microservices-app
RELEASE_NAME := myapp
NAMESPACE := microservices-dev

# Validate the Helm chart
validate:
	@echo "Validating Helm chart..."
	@if [ -f "scripts/validate.sh" ]; then \
		bash scripts/validate.sh; \
	else \
		helm lint .; \
		helm dependency build .; \
		helm dependency update .; \
	fi

# Lint the Helm chart
lint:
	@echo "Linting Helm chart..."
	helm lint .

# Test template rendering
test:
	@echo "Testing template rendering..."
	@echo "Testing with values-dev.yaml..."
	helm template test-release . -f values-dev.yaml > /dev/null
	@echo "Testing with values-staging.yaml..."
	helm template test-release . -f values-staging.yaml > /dev/null
	@echo "Testing with values-prod.yaml..."
	helm template test-release . -f values-prod.yaml > /dev/null
	@echo "All template tests passed!"

# Install the chart (development)
install:
	@echo "Installing chart in development mode..."
	helm install $(RELEASE_NAME) . -f values-dev.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m

# Install the chart (staging)
install-staging:
	@echo "Installing chart in staging mode..."
	helm install $(RELEASE_NAME) . -f values-staging.yaml \
		--namespace microservices-staging \
		--create-namespace \
		--wait \
		--timeout 10m

# Install the chart (production)
install-prod:
	@echo "Installing chart in production mode..."
	helm install $(RELEASE_NAME) . -f values-prod.yaml \
		--namespace microservices-prod \
		--create-namespace \
		--wait \
		--timeout 15m

# Upgrade the chart
upgrade:
	@echo "Upgrading chart..."
	helm upgrade $(RELEASE_NAME) . -f values-dev.yaml \
		--atomic \
		--timeout 10m

# Upgrade the chart (staging)
upgrade-staging:
	@echo "Upgrading chart in staging..."
	helm upgrade $(RELEASE_NAME) . -f values-staging.yaml \
		--atomic \
		--timeout 10m

# Upgrade the chart (production)
upgrade-prod:
	@echo "Upgrading chart in production..."
	helm upgrade $(RELEASE_NAME) . -f values-prod.yaml \
		--atomic \
		--timeout 15m

# Uninstall the chart
uninstall:
	@echo "Uninstalling chart..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

# Uninstall the chart (staging)
uninstall-staging:
	@echo "Uninstalling chart from staging..."
	helm uninstall $(RELEASE_NAME) --namespace microservices-staging

# Uninstall the chart (production)
uninstall-prod:
	@echo "Uninstalling chart from production..."
	helm uninstall $(RELEASE_NAME) --namespace microservices-prod

# Clean up generated files
clean:
	@echo "Cleaning up generated files..."
	rm -rf charts/
	rm -rf .helmignore
	@echo "Cleanup completed!"

# Generate documentation
docs:
	@echo "Generating documentation..."
	@if command -v helm-docs >/dev/null 2>&1; then \
		helm-docs --chart-search-root=. --output-file=README.md; \
	else \
		echo "helm-docs not found. Install with: go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest"; \
	fi

# Show chart status
status:
	@echo "Chart status:"
	helm list --namespace $(NAMESPACE)

# Show chart status (staging)
status-staging:
	@echo "Chart status (staging):"
	helm list --namespace microservices-staging

# Show chart status (production)
status-prod:
	@echo "Chart status (production):"
	helm list --namespace microservices-prod

# Show chart values
values:
	@echo "Chart values:"
	helm get values $(RELEASE_NAME) --namespace $(NAMESPACE)

# Show chart values (staging)
values-staging:
	@echo "Chart values (staging):"
	helm get values $(RELEASE_NAME) --namespace microservices-staging

# Show chart values (production)
values-prod:
	@echo "Chart values (production):"
	helm get values $(RELEASE_NAME) --namespace microservices-prod

# Rollback chart
rollback:
	@echo "Rolling back chart..."
	helm rollback $(RELEASE_NAME) --namespace $(NAMESPACE)

# Rollback chart (staging)
rollback-staging:
	@echo "Rolling back chart (staging)..."
	helm rollback $(RELEASE_NAME) --namespace microservices-staging

# Rollback chart (production)
rollback-prod:
	@echo "Rolling back chart (production)..."
	helm rollback $(RELEASE_NAME) --namespace microservices-prod

# Test chart with dry-run
dry-run:
	@echo "Testing chart installation with dry-run..."
	helm install $(RELEASE_NAME) . -f values-dev.yaml \
		--namespace $(NAMESPACE) \
		--dry-run

# Test chart with dry-run (staging)
dry-run-staging:
	@echo "Testing chart installation with dry-run (staging)..."
	helm install $(RELEASE_NAME) . -f values-staging.yaml \
		--namespace microservices-staging \
		--dry-run

# Test chart with dry-run (production)
dry-run-prod:
	@echo "Testing chart installation with dry-run (production)..."
	helm install $(RELEASE_NAME) . -f values-prod.yaml \
		--namespace microservices-prod \
		--dry-run

# Package chart
package:
	@echo "Packaging chart..."
	helm package .

# Show chart history
history:
	@echo "Chart history:"
	helm history $(RELEASE_NAME) --namespace $(NAMESPACE)

# Show chart history (staging)
history-staging:
	@echo "Chart history (staging):"
	helm history $(RELEASE_NAME) --namespace microservices-staging

# Show chart history (production)
history-prod:
	@echo "Chart history (production):"
	helm history $(RELEASE_NAME) --namespace microservices-prod

# =============================================================================
# KUBEDIAGRAMS INTEGRATION
# =============================================================================

# Install KubeDiagrams tool
install-kubediagrams:
	@echo "Installing KubeDiagrams..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -i; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

# Generate architecture diagrams for all environments
diagrams:
	@echo "Generating architecture diagrams..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

# Generate diagrams for specific environment
diagrams-dev:
	@echo "Generating diagrams for development environment..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -e dev; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

diagrams-staging:
	@echo "Generating diagrams for staging environment..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -e staging; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

diagrams-prod:
	@echo "Generating diagrams for production environment..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -e prod; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

# Set up interactive viewer only
diagrams-viewer:
	@echo "Setting up interactive viewer..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -v; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

# Clean diagrams and regenerate
diagrams-clean:
	@echo "Cleaning and regenerating diagrams..."
	@if [ -f "scripts/generate-diagrams.sh" ]; then \
		bash scripts/generate-diagrams.sh -c; \
	else \
		echo "Error: generate-diagrams.sh not found"; \
		exit 1; \
	fi

# =============================================================================
# AWS IAM AUTHENTICATOR INTEGRATION
# =============================================================================

# Setup AWS IAM Authenticator
setup-aws-iam:
	@echo "Setting up AWS IAM Authenticator..."
	@if [ -f "scripts/setup-aws-iam-authenticator.sh" ]; then \
		chmod +x scripts/setup-aws-iam-authenticator.sh; \
		bash scripts/setup-aws-iam-authenticator.sh; \
	else \
		echo "Error: setup-aws-iam-authenticator.sh not found"; \
		exit 1; \
	fi

# Setup AWS IAM Authenticator for specific cluster
setup-aws-iam-cluster:
	@echo "Setting up AWS IAM Authenticator for specific cluster..."
	@if [ -f "scripts/setup-aws-iam-authenticator.sh" ]; then \
		chmod +x scripts/setup-aws-iam-authenticator.sh; \
		bash scripts/setup-aws-iam-authenticator.sh -c $(CLUSTER_NAME); \
	else \
		echo "Error: setup-aws-iam-authenticator.sh not found"; \
		exit 1; \
	fi

# Update values.yaml with AWS account ID
update-aws-values:
	@echo "Updating values.yaml with AWS account ID..."
	@if [ -f "scripts/setup-aws-iam-authenticator.sh" ]; then \
		chmod +x scripts/setup-aws-iam-authenticator.sh; \
		bash scripts/setup-aws-iam-authenticator.sh --update-values; \
	else \
		echo "Error: setup-aws-iam-authenticator.sh not found"; \
		exit 1; \
	fi

# Generate kubeconfig for AWS IAM Authenticator
generate-aws-kubeconfig:
	@echo "Generating kubeconfig for AWS IAM Authenticator..."
	@if [ -f "scripts/setup-aws-iam-authenticator.sh" ]; then \
		chmod +x scripts/setup-aws-iam-authenticator.sh; \
		bash scripts/setup-aws-iam-authenticator.sh --generate-kubeconfig; \
	else \
		echo "Error: setup-aws-iam-authenticator.sh not found"; \
		exit 1; \
	fi

# Test AWS IAM Authenticator authentication
test-aws-auth:
	@echo "Testing AWS IAM Authenticator authentication..."
	@if [ -f "kubeconfig-aws-iam-authenticator.yaml" ]; then \
		kubectl --kubeconfig kubeconfig-aws-iam-authenticator.yaml get pods --all-namespaces; \
	else \
		echo "Error: kubeconfig-aws-iam-authenticator.yaml not found. Run 'make generate-aws-kubeconfig' first."; \
		exit 1; \
	fi 

# =============================================================================
# KUBECTL-COST INTEGRATION
# =============================================================================

# Setup kubectl-cost
setup-kubectl-cost:
	@echo "Setting up kubectl-cost..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Install kubectl-cost plugin only
install-kubectl-cost-plugin:
	@echo "Installing kubectl-cost plugin..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh --configure; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Install Kubecost cost analyzer
install-kubecost:
	@echo "Installing Kubecost cost analyzer..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh --install-kubecost; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Test kubectl-cost functionality
test-kubectl-cost:
	@echo "Testing kubectl-cost functionality..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh --test; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Generate cost analysis examples
cost-examples:
	@echo "Generating cost analysis examples..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh --examples; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Create cost monitoring dashboard
cost-dashboard:
	@echo "Creating cost monitoring dashboard..."
	@if [ -f "scripts/setup-kubectl-cost.sh" ]; then \
		chmod +x scripts/setup-kubectl-cost.sh; \
		bash scripts/setup-kubectl-cost.sh --dashboard; \
	else \
		echo "Error: setup-kubectl-cost.sh not found"; \
		exit 1; \
	fi

# Cost analysis commands
cost-daily:
	@echo "Daily cost allocation analysis..."
	@kubectl cost allocation --window 1d --aggregate namespace

cost-weekly:
	@echo "Weekly cost allocation analysis..."
	@kubectl cost allocation --window 7d --aggregate namespace

cost-monthly:
	@echo "Monthly cost allocation analysis..."
	@kubectl cost allocation --window 30d --aggregate namespace

cost-efficiency:
	@echo "Cost efficiency analysis..."
	@kubectl cost allocation --window 7d --aggregate pod --show-efficiency

cost-optimization:
	@echo "Cost optimization recommendations..."
	@kubectl cost allocation --window 7d --aggregate pod --show-efficiency --recommendations

cost-export-csv:
	@echo "Exporting cost data to CSV..."
	@kubectl cost allocation --window 7d --aggregate namespace --format csv > cost-report-$(shell date +%Y%m%d).csv

cost-export-json:
	@echo "Exporting cost data to JSON..."
	@kubectl cost allocation --window 7d --aggregate namespace --format json > cost-report-$(shell date +%Y%m%d).json

# Port forward to Kubecost dashboard
kubecost-port-forward:
	@echo "Starting port forward to Kubecost dashboard..."
	@kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090 