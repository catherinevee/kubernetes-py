#!/bin/bash

# =============================================================================
# HELM CHART VALIDATION SCRIPT
# =============================================================================
# Validates the microservices-app Helm chart for syntax, dependencies, and best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists helm; then
        print_error "Helm is not installed. Please install Helm v3.8+"
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_warning "kubectl is not installed. Some validations will be skipped."
    fi
    
    if ! command_exists yamllint; then
        print_warning "yamllint is not installed. YAML syntax validation will be skipped."
    fi
    
    print_success "Prerequisites check completed"
}

# Validate Helm chart structure
validate_chart_structure() {
    print_status "Validating Helm chart structure..."
    
    local chart_dir="."
    local required_files=("Chart.yaml" "values.yaml" "templates/")
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$chart_dir/$file" ]]; then
            print_error "Required file/directory missing: $file"
            exit 1
        fi
    done
    
    print_success "Chart structure validation passed"
}

# Lint Helm chart
lint_chart() {
    print_status "Linting Helm chart..."
    
    if helm lint .; then
        print_success "Helm chart linting passed"
    else
        print_error "Helm chart linting failed"
        exit 1
    fi
}

# Validate dependencies
validate_dependencies() {
    print_status "Validating chart dependencies..."
    
    if helm dependency build .; then
        print_success "Dependencies built successfully"
    else
        print_error "Failed to build dependencies"
        exit 1
    fi
    
    if helm dependency update .; then
        print_success "Dependencies updated successfully"
    else
        print_error "Failed to update dependencies"
        exit 1
    fi
}

# Template validation
validate_templates() {
    print_status "Validating Helm templates..."
    
    # Test template rendering for different environments
    local environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        local values_file="values-${env}.yaml"
        if [[ -f "$values_file" ]]; then
            print_status "Testing template rendering with $values_file"
            if helm template test-release . -f "$values_file" > /dev/null; then
                print_success "Template rendering with $values_file passed"
            else
                print_error "Template rendering with $values_file failed"
                exit 1
            fi
        else
            print_warning "Values file $values_file not found, skipping"
        fi
    done
}

# YAML syntax validation
validate_yaml_syntax() {
    if command_exists yamllint; then
        print_status "Validating YAML syntax..."
        
        # Find all YAML files
        local yaml_files=$(find . -name "*.yaml" -o -name "*.yml")
        
        for file in $yaml_files; do
            if yamllint "$file" > /dev/null 2>&1; then
                print_success "YAML syntax validation passed for $file"
            else
                print_error "YAML syntax validation failed for $file"
                yamllint "$file"
                exit 1
            fi
        done
    else
        print_warning "yamllint not available, skipping YAML syntax validation"
    fi
}

# Security validation
validate_security() {
    print_status "Validating security configurations..."
    
    # Check for hardcoded secrets in values files
    local values_files=$(find . -name "values*.yaml")
    
    for file in $values_files; do
        if grep -q "password\|secret\|key" "$file"; then
            print_warning "Potential secrets found in $file - review manually"
        fi
    done
    
    # Check for security contexts in templates
    if grep -r "securityContext" templates/ > /dev/null; then
        print_success "Security contexts found in templates"
    else
        print_warning "No security contexts found in templates"
    fi
    
    # Check for network policies
    if grep -r "NetworkPolicy" templates/ > /dev/null; then
        print_success "Network policies found in templates"
    else
        print_warning "No network policies found in templates"
    fi
}

# Resource validation
validate_resources() {
    print_status "Validating resource configurations..."
    
    # Check for resource requests and limits
    if grep -r "resources:" templates/ > /dev/null; then
        print_success "Resource configurations found in templates"
    else
        print_warning "No resource configurations found in templates"
    fi
    
    # Check for resource quotas
    if grep -r "ResourceQuota" templates/ > /dev/null; then
        print_success "Resource quotas found in templates"
    else
        print_warning "No resource quotas found in templates"
    fi
}

# Monitoring validation
validate_monitoring() {
    print_status "Validating monitoring configurations..."
    
    # Check for ServiceMonitors
    if grep -r "ServiceMonitor" templates/ > /dev/null; then
        print_success "ServiceMonitors found in templates"
    else
        print_warning "No ServiceMonitors found in templates"
    fi
    
    # Check for PrometheusRules
    if grep -r "PrometheusRule" templates/ > /dev/null; then
        print_success "PrometheusRules found in templates"
    else
        print_warning "No PrometheusRules found in templates"
    fi
}

# Kubernetes API validation
validate_k8s_api() {
    if command_exists kubectl; then
        print_status "Validating Kubernetes API compatibility..."
        
        # Test with different Kubernetes versions
        local k8s_versions=("1.24" "1.25" "1.26" "1.27")
        
        for version in "${k8s_versions[@]}"; do
            print_status "Testing with Kubernetes $version"
            if helm template test-release . -f values-dev.yaml | kubectl apply --dry-run=client --server-side --server-dry-run --kube-version="$version" -f - > /dev/null 2>&1; then
                print_success "Kubernetes $version compatibility passed"
            else
                print_warning "Kubernetes $version compatibility issues detected"
            fi
        done
    else
        print_warning "kubectl not available, skipping Kubernetes API validation"
    fi
}

# Main validation function
main() {
    print_status "Starting Helm chart validation..."
    
    check_prerequisites
    validate_chart_structure
    lint_chart
    validate_dependencies
    validate_templates
    validate_yaml_syntax
    validate_security
    validate_resources
    validate_monitoring
    validate_k8s_api
    
    print_success "All validations completed successfully!"
}

# Run main function
main "$@" 