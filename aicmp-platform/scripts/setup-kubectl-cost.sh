#!/bin/bash

# =============================================================================
# KUBECTL-COST SETUP SCRIPT
# =============================================================================
# This script helps set up kubectl-cost for Kubernetes cost monitoring and
# optimization. It installs the kubectl-cost plugin, configures it for use
# with Kubecost, and provides cost analysis capabilities.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")"
KUBECOST_NAMESPACE="kubecost"
KUBECOST_RELEASE_NAME="kubecost"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if Helm is available
    if ! command -v helm &> /dev/null; then
        print_error "Helm is required but not installed. Please install Helm first."
        exit 1
    fi
    
    # Check if kubectl-cost plugin is available
    if ! kubectl cost --help &> /dev/null; then
        print_warning "kubectl-cost plugin is not installed. Will install it now."
        install_kubectl_cost_plugin
    else
        print_success "kubectl-cost plugin is already installed"
    fi
    
    # Check if kubectl can access the cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot access Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to install kubectl-cost plugin
install_kubectl_cost_plugin() {
    print_status "Installing kubectl-cost plugin..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download and install kubectl-cost
    VERSION=$(curl -s https://api.github.com/repos/kubecost/kubectl-cost/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    print_status "Downloading kubectl-cost version $VERSION..."
    
    curl -L -o kubectl-cost.tar.gz "https://github.com/kubecost/kubectl-cost/releases/download/${VERSION}/kubectl-cost-${VERSION}-${OS}-${ARCH}.tar.gz"
    
    tar -xzf kubectl-cost.tar.gz
    chmod +x kubectl-cost
    
    # Install to system path
    if [[ "$OS" == "darwin" ]]; then
        sudo mv kubectl-cost /usr/local/bin/
    else
        sudo mv kubectl-cost /usr/local/bin/
    fi
    
    rm kubectl-cost.tar.gz
    
    print_success "kubectl-cost plugin installed successfully"
}

# Function to install Kubecost
install_kubecost() {
    print_status "Installing Kubecost..."
    
    # Add Kubecost Helm repository
    helm repo add kubecost https://kubecost.github.io/cost-analyzer/
    helm repo update
    
    # Create kubecost namespace if it doesn't exist
    kubectl create namespace $KUBECOST_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Kubecost
    helm install $KUBECOST_RELEASE_NAME kubecost/cost-analyzer \
        --namespace $KUBECOST_NAMESPACE \
        --set kubecostToken="your-kubecost-token" \
        --set prometheus.kube-state-metrics.enabled=false \
        --set prometheus.node-exporter.enabled=false \
        --set prometheus.serviceAccounts.node-exporter.create=false \
        --set prometheus.serviceAccounts.kube-state-metrics.create=false \
        --wait \
        --timeout 10m
    
    print_success "Kubecost installed successfully"
}

# Function to configure kubectl-cost
configure_kubectl_cost() {
    print_status "Configuring kubectl-cost..."
    
    # Wait for Kubecost to be ready
    print_status "Waiting for Kubecost to be ready..."
    kubectl wait --for=condition=ready pod -l app=cost-analyzer -n $KUBECOST_NAMESPACE --timeout=300s
    
    # Get Kubecost service URL
    KUBECOST_SERVICE_URL=$(kubectl get svc -n $KUBECOST_NAMESPACE $KUBECOST_RELEASE_NAME-cost-analyzer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [[ -z "$KUBECOST_SERVICE_URL" ]]; then
        # Use port-forward if LoadBalancer is not available
        print_warning "LoadBalancer not available, using port-forward..."
        KUBECOST_SERVICE_URL="localhost:9090"
        kubectl port-forward -n $KUBECOST_NAMESPACE svc/$KUBECOST_RELEASE_NAME-cost-analyzer 9090:9090 &
        PORT_FORWARD_PID=$!
        sleep 5
    fi
    
    # Test kubectl-cost connection
    print_status "Testing kubectl-cost connection..."
    if kubectl cost allocation --window 1d --service kubecost-cost-analyzer; then
        print_success "kubectl-cost is working correctly"
    else
        print_error "Failed to connect to Kubecost. Please check the installation."
        exit 1
    fi
    
    # Kill port-forward if it was started
    if [[ -n "$PORT_FORWARD_PID" ]]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

# Function to create cost analysis examples
create_cost_examples() {
    print_status "Creating cost analysis examples..."
    
    cat > "${CHART_DIR}/examples/cost-analysis-examples.md" << 'EOF'
# Kubectl-Cost Analysis Examples

## Basic Cost Analysis

### Daily allocation costs
```bash
kubectl cost allocation --window 1d
```

### Weekly allocation costs by namespace
```bash
kubectl cost allocation --window 7d --aggregate namespace
```

### Monthly allocation costs by pod
```bash
kubectl cost allocation --window 30d --aggregate pod
```

## Cost Optimization

### Resource efficiency analysis
```bash
kubectl cost allocation --window 7d --aggregate pod --show-efficiency
```

### Idle resource costs
```bash
kubectl cost allocation --window 7d --include-idle
```

### Shared resource costs
```bash
kubectl cost allocation --window 7d --include-shared
```

## Cost Forecasting

### Predict future costs
```bash
kubectl cost allocation --window 30d --forecast
```

### Budget analysis
```bash
kubectl cost allocation --window 30d --budget 1000
```

## Export and Reporting

### Export to CSV
```bash
kubectl cost allocation --window 7d --aggregate namespace --format csv > cost-report.csv
```

### Export to JSON
```bash
kubectl cost allocation --window 7d --aggregate pod --format json > cost-report.json
```

## Advanced Analysis

### Cost by label
```bash
kubectl cost allocation --window 7d --aggregate label:app
```

### Cost by service
```bash
kubectl cost allocation --window 7d --aggregate service
```

### Cost by deployment
```bash
kubectl cost allocation --window 7d --aggregate deployment
```

## Monitoring and Alerts

### Check for cost anomalies
```bash
kubectl cost allocation --window 1d --anomaly
```

### Resource utilization
```bash
kubectl cost allocation --window 7d --show-efficiency --aggregate pod
```

## Cost Optimization Recommendations

### Right-sizing recommendations
```bash
kubectl cost allocation --window 7d --aggregate pod --show-efficiency --recommendations
```

### Spot instance opportunities
```bash
kubectl cost allocation --window 7d --aggregate pod --spot-recommendations
```

### Reserved instance analysis
```bash
kubectl cost allocation --window 30d --aggregate pod --reserved-instance-analysis
```
EOF
    
    print_success "Cost analysis examples created"
}

# Function to create cost monitoring dashboard
create_cost_dashboard() {
    print_status "Creating cost monitoring dashboard..."
    
    cat > "${CHART_DIR}/examples/cost-dashboard.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-dashboard
  namespace: kubecost
data:
  cost-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Kubernetes Cost Analysis",
        "tags": ["kubernetes", "cost", "monitoring"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Daily Cost Allocation",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total[1h])) by (pod)",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 2,
            "title": "Memory Usage by Namespace",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(container_memory_usage_bytes) by (namespace)",
                "legendFormat": "{{namespace}}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Cost Efficiency",
            "type": "stat",
            "targets": [
              {
                "expr": "kubecost_allocation_efficiency_ratio",
                "legendFormat": "Efficiency Ratio"
              }
            ]
          }
        ]
      }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: cost-dashboard
  namespace: kubecost
spec:
  selector:
    app: cost-dashboard
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF
    
    print_success "Cost monitoring dashboard created"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Set up kubectl-cost for Kubernetes cost monitoring and optimization.

OPTIONS:
    -h, --help              Show this help message
    --install-kubecost      Install Kubecost cost analyzer
    --configure             Configure kubectl-cost
    --examples              Create cost analysis examples
    --dashboard             Create cost monitoring dashboard
    --test                  Test kubectl-cost functionality

EXAMPLES:
    $0                      Full setup with default settings
    $0 --install-kubecost   Install Kubecost only
    $0 --configure          Configure kubectl-cost only
    $0 --test               Test kubectl-cost functionality

PREREQUISITES:
    - kubectl configured to access the Kubernetes cluster
    - Helm installed
    - Internet access to download kubectl-cost plugin

OUTPUT:
    - kubectl-cost plugin installed
    - Kubecost cost analyzer (optional)
    - Cost analysis examples
    - Cost monitoring dashboard
    - Configuration files
EOF
}

# Function to test kubectl-cost
test_kubectl_cost() {
    print_status "Testing kubectl-cost functionality..."
    
    # Test basic functionality
    print_status "Testing basic cost allocation..."
    if kubectl cost allocation --window 1d --aggregate namespace; then
        print_success "Basic cost allocation test passed"
    else
        print_error "Basic cost allocation test failed"
        return 1
    fi
    
    # Test efficiency analysis
    print_status "Testing efficiency analysis..."
    if kubectl cost allocation --window 7d --aggregate pod --show-efficiency; then
        print_success "Efficiency analysis test passed"
    else
        print_warning "Efficiency analysis test failed (may not be available)"
    fi
    
    # Test export functionality
    print_status "Testing export functionality..."
    if kubectl cost allocation --window 1d --aggregate namespace --format csv > /tmp/test-cost.csv; then
        print_success "Export functionality test passed"
        rm /tmp/test-cost.csv
    else
        print_error "Export functionality test failed"
        return 1
    fi
    
    print_success "All kubectl-cost tests passed"
}

# Main function
main() {
    local install_kubecost=false
    local configure_only=false
    local examples_only=false
    local dashboard_only=false
    local test_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --install-kubecost)
                install_kubecost=true
                shift
                ;;
            --configure)
                configure_only=true
                shift
                ;;
            --examples)
                examples_only=true
                shift
                ;;
            --dashboard)
                dashboard_only=true
                shift
                ;;
            --test)
                test_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Starting kubectl-cost setup..."
    
    # Check prerequisites
    check_prerequisites
    
    if [[ "$test_only" == true ]]; then
        test_kubectl_cost
        exit 0
    fi
    
    if [[ "$examples_only" == true ]]; then
        create_cost_examples
        exit 0
    fi
    
    if [[ "$dashboard_only" == true ]]; then
        create_cost_dashboard
        exit 0
    fi
    
    # Install Kubecost if requested
    if [[ "$install_kubecost" == true ]]; then
        install_kubecost
    fi
    
    # Configure kubectl-cost
    if [[ "$configure_only" == true ]] || [[ "$install_kubecost" == true ]]; then
        configure_kubectl_cost
    fi
    
    # Create examples and dashboard
    if [[ "$configure_only" == false ]]; then
        create_cost_examples
        create_cost_dashboard
    fi
    
    print_success "kubectl-cost setup completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Test kubectl-cost: kubectl cost allocation --window 1d"
    print_status "2. View examples: cat examples/cost-analysis-examples.md"
    print_status "3. Access cost dashboard: kubectl port-forward -n kubecost svc/cost-dashboard 3000:3000"
    print_status ""
    print_status "For more information, see the README.md file."
}

# Run main function with all arguments
main "$@" 