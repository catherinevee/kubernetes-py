#!/bin/bash

# =============================================================================
# KUBEDIAGRAMS INTEGRATION SCRIPT
# =============================================================================
# This script generates Kubernetes architecture diagrams using KubeDiagrams
# for the microservices application deployment.

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
DIAGRAMS_DIR="${CHART_DIR}/diagrams"
TEMPLATES_DIR="${CHART_DIR}/templates"
VALUES_FILE="${CHART_DIR}/values.yaml"

# KubeDiagrams configuration
KUBEDIAGRAMS_VERSION="0.4.0"
KUBEDIAGRAMS_BINARY="kube-diagrams"
OUTPUT_FORMATS=("dot" "svg" "png" "dot_json")

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
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Helm is available
    if ! command -v helm &> /dev/null; then
        print_error "Helm is required but not installed. Please install Helm first."
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed. Please install kubectl first."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to install KubeDiagrams
install_kubediagrams() {
    print_status "Installing KubeDiagrams..."
    
    # Check if KubeDiagrams is already installed
    if command -v "$KUBEDIAGRAMS_BINARY" &> /dev/null; then
        print_success "KubeDiagrams is already installed"
        return 0
    fi
    
    # Install KubeDiagrams using Docker
    print_status "Pulling KubeDiagrams Docker image..."
    docker pull philippemerle/kubediagrams:${KUBEDIAGRAMS_VERSION}
    
    # Create a wrapper script for KubeDiagrams
    cat > "${SCRIPT_DIR}/${KUBEDIAGRAMS_BINARY}" << 'EOF'
#!/bin/bash
docker run --rm -v "$(pwd):/workspace" -w /workspace philippemerle/kubediagrams:0.4.0 "$@"
EOF
    
    chmod +x "${SCRIPT_DIR}/${KUBEDIAGRAMS_BINARY}"
    
    # Add to PATH for this session
    export PATH="${SCRIPT_DIR}:$PATH"
    
    print_success "KubeDiagrams installed successfully"
}

# Function to create diagrams directory
create_diagrams_directory() {
    print_status "Creating diagrams directory..."
    
    mkdir -p "$DIAGRAMS_DIR"
    
    # Create .gitkeep to preserve directory in git
    touch "${DIAGRAMS_DIR}/.gitkeep"
    
    print_success "Diagrams directory created: $DIAGRAMS_DIR"
}

# Function to generate Helm template YAML
generate_helm_templates() {
    local environment=${1:-"default"}
    local output_dir="${DIAGRAMS_DIR}/helm-templates-${environment}"
    
    print_status "Generating Helm templates for environment: $environment"
    
    mkdir -p "$output_dir"
    
    # Generate templates using Helm
    if [[ "$environment" == "default" ]]; then
        helm template microservices-app "$CHART_DIR" \
            --output-dir "$output_dir" \
            --debug
    else
        helm template microservices-app "$CHART_DIR" \
            -f "${CHART_DIR}/values-${environment}.yaml" \
            --output-dir "$output_dir" \
            --debug
    fi
    
    print_success "Helm templates generated in: $output_dir"
    echo "$output_dir"
}

# Function to generate diagrams from YAML files
generate_diagrams() {
    local yaml_dir="$1"
    local environment=${2:-"default"}
    local output_prefix="microservices-${environment}"
    
    print_status "Generating diagrams from YAML files in: $yaml_dir"
    
    # Ensure KubeDiagrams is in PATH
    export PATH="${SCRIPT_DIR}:$PATH"
    
    # Generate diagrams in different formats
    for format in "${OUTPUT_FORMATS[@]}"; do
        print_status "Generating $format diagram..."
        
        local output_file="${DIAGRAMS_DIR}/${output_prefix}.${format}"
        
        if "$KUBEDIAGRAMS_BINARY" "$yaml_dir"/*.yaml -o "$output_file"; then
            print_success "Generated $format diagram: $output_file"
        else
            print_warning "Failed to generate $format diagram"
        fi
    done
}

# Function to generate custom diagram with annotations
generate_custom_diagram() {
    local environment=${1:-"default"}
    local custom_file="${DIAGRAMS_DIR}/custom-${environment}.kd"
    
    print_status "Generating custom diagram configuration..."
    
    # Create custom diagram configuration
    cat > "$custom_file" << EOF
# Custom diagram configuration for microservices application
# Environment: $environment

# Custom clusters
clusters:
  - name: "AWS EKS Cluster"
    label: "Amazon Elastic Kubernetes Service"
  
  - name: "Application Namespace"
    label: "Microservices Application Namespace"
  
  - name: "Monitoring Stack"
    label: "Prometheus & Grafana Monitoring"

# Custom nodes
nodes:
  - name: "External Users"
    label: "External Users"
    cluster: "AWS EKS Cluster"
  
  - name: "AWS Load Balancer"
    label: "Application Load Balancer (ALB)"
    cluster: "AWS EKS Cluster"
  
  - name: "WAF"
    label: "AWS WAF"
    cluster: "AWS EKS Cluster"

# Custom edges
edges:
  - from: "External Users"
    to: "AWS Load Balancer"
    label: "HTTPS Traffic"
  
  - from: "AWS Load Balancer"
    to: "WAF"
    label: "Security Check"
  
  - from: "WAF"
    to: "web-tier"
    label: "Filtered Traffic"

# Include generated resources
include:
  - "${DIAGRAMS_DIR}/helm-templates-${environment}/*.yaml"
EOF
    
    print_success "Custom diagram configuration created: $custom_file"
    
    # Generate custom diagram
    local output_file="${DIAGRAMS_DIR}/custom-${environment}.dot_json"
    if "$KUBEDIAGRAMS_BINARY" "$custom_file" -o "$output_file"; then
        print_success "Generated custom diagram: $output_file"
    else
        print_warning "Failed to generate custom diagram"
    fi
}

# Function to create interactive viewer
setup_interactive_viewer() {
    print_status "Setting up KubeDiagrams Interactive Viewer..."
    
    local viewer_dir="${DIAGRAMS_DIR}/interactive-viewer"
    
    # Create interactive viewer directory
    mkdir -p "$viewer_dir"
    
    # Download interactive viewer files
    print_status "Downloading interactive viewer files..."
    
    # Create a simple HTML viewer
    cat > "${viewer_dir}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microservices Architecture Diagrams</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        .diagram-section {
            margin-bottom: 30px;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .diagram-section h2 {
            color: #555;
            margin-top: 0;
        }
        .diagram-links {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .diagram-link {
            padding: 8px 16px;
            background-color: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-size: 14px;
        }
        .diagram-link:hover {
            background-color: #0056b3;
        }
        .environment-tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .environment-tab {
            padding: 10px 20px;
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 4px;
            cursor: pointer;
            text-decoration: none;
            color: #333;
        }
        .environment-tab.active {
            background-color: #007bff;
            color: white;
            border-color: #007bff;
        }
        .instructions {
            background-color: #e7f3ff;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Microservices Application Architecture Diagrams</h1>
        
        <div class="instructions">
            <h3>📋 Instructions</h3>
            <p>This page provides access to automatically generated Kubernetes architecture diagrams for the microservices application. 
            Diagrams are generated using <a href="https://github.com/philippemerle/KubeDiagrams" target="_blank">KubeDiagrams</a>.</p>
            <ul>
                <li><strong>SVG/PNG:</strong> Static diagrams for documentation</li>
                <li><strong>DOT:</strong> Graphviz source files for customization</li>
                <li><strong>DOT_JSON:</strong> Interactive diagrams (open in browser)</li>
            </ul>
        </div>

        <div class="environment-tabs">
            <a href="#development" class="environment-tab active">Development</a>
            <a href="#staging" class="environment-tab">Staging</a>
            <a href="#production" class="environment-tab">Production</a>
        </div>

        <div id="development" class="diagram-section">
            <h2>🏗️ Development Environment</h2>
            <div class="diagram-links">
                <a href="microservices-dev.svg" class="diagram-link" target="_blank">SVG Diagram</a>
                <a href="microservices-dev.png" class="diagram-link" target="_blank">PNG Diagram</a>
                <a href="microservices-dev.dot" class="diagram-link" target="_blank">DOT Source</a>
                <a href="microservices-dev.dot_json" class="diagram-link" target="_blank">Interactive</a>
                <a href="custom-dev.dot_json" class="diagram-link" target="_blank">Custom Interactive</a>
            </div>
        </div>

        <div id="staging" class="diagram-section" style="display: none;">
            <h2>🔧 Staging Environment</h2>
            <div class="diagram-links">
                <a href="microservices-staging.svg" class="diagram-link" target="_blank">SVG Diagram</a>
                <a href="microservices-staging.png" class="diagram-link" target="_blank">PNG Diagram</a>
                <a href="microservices-staging.dot" class="diagram-link" target="_blank">DOT Source</a>
                <a href="microservices-staging.dot_json" class="diagram-link" target="_blank">Interactive</a>
                <a href="custom-staging.dot_json" class="diagram-link" target="_blank">Custom Interactive</a>
            </div>
        </div>

        <div id="production" class="diagram-section" style="display: none;">
            <h2>🚀 Production Environment</h2>
            <div class="diagram-links">
                <a href="microservices-prod.svg" class="diagram-link" target="_blank">SVG Diagram</a>
                <a href="microservices-prod.png" class="diagram-link" target="_blank">PNG Diagram</a>
                <a href="microservices-prod.dot" class="diagram-link" target="_blank">DOT Source</a>
                <a href="microservices-prod.dot_json" class="diagram-link" target="_blank">Interactive</a>
                <a href="custom-prod.dot_json" class="diagram-link" target="_blank">Custom Interactive</a>
            </div>
        </div>
    </div>

    <script>
        // Tab switching functionality
        document.querySelectorAll('.environment-tab').forEach(tab => {
            tab.addEventListener('click', function(e) {
                e.preventDefault();
                
                // Remove active class from all tabs
                document.querySelectorAll('.environment-tab').forEach(t => t.classList.remove('active'));
                
                // Add active class to clicked tab
                this.classList.add('active');
                
                // Hide all sections
                document.querySelectorAll('.diagram-section').forEach(section => {
                    section.style.display = 'none';
                });
                
                // Show corresponding section
                const targetId = this.getAttribute('href').substring(1);
                document.getElementById(targetId).style.display = 'block';
            });
        });
    </script>
</body>
</html>
EOF
    
    print_success "Interactive viewer created: ${viewer_dir}/index.html"
}

# Function to generate diagrams for all environments
generate_all_diagrams() {
    print_status "Generating diagrams for all environments..."
    
    local environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        print_status "Processing environment: $env"
        
        # Generate Helm templates
        local yaml_dir=$(generate_helm_templates "$env")
        
        # Generate diagrams
        generate_diagrams "$yaml_dir" "$env"
        
        # Generate custom diagram
        generate_custom_diagram "$env"
    done
    
    # Also generate default diagrams
    print_status "Processing default environment"
    local default_yaml_dir=$(generate_helm_templates "default")
    generate_diagrams "$default_yaml_dir" "default"
    generate_custom_diagram "default"
}

# Function to clean up temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    
    # Remove temporary YAML directories
    find "$DIAGRAMS_DIR" -name "helm-templates-*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ENVIRONMENT]

Generate Kubernetes architecture diagrams using KubeDiagrams for the microservices application.

OPTIONS:
    -h, --help              Show this help message
    -e, --environment ENV   Generate diagrams for specific environment (dev|staging|prod|all)
    -c, --clean             Clean up temporary files
    -i, --install-only      Only install KubeDiagrams without generating diagrams
    -v, --viewer            Set up interactive viewer only

ENVIRONMENT:
    dev                     Development environment
    staging                 Staging environment  
    prod                    Production environment
    all                     All environments (default)

EXAMPLES:
    $0                      Generate diagrams for all environments
    $0 -e dev              Generate diagrams for development environment only
    $0 -e prod -c          Generate production diagrams and clean up
    $0 -i                  Install KubeDiagrams only
    $0 -v                  Set up interactive viewer only

OUTPUT:
    Diagrams will be generated in: $DIAGRAMS_DIR
    Interactive viewer: $DIAGRAMS_DIR/interactive-viewer/index.html
EOF
}

# Main function
main() {
    local environment="all"
    local cleanup_flag=false
    local install_only=false
    local viewer_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -c|--clean)
                cleanup_flag=true
                shift
                ;;
            -i|--install-only)
                install_only=true
                shift
                ;;
            -v|--viewer)
                viewer_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Starting KubeDiagrams integration for microservices application"
    
    # Check prerequisites
    check_prerequisites
    
    # Install KubeDiagrams
    install_kubediagrams
    
    if [[ "$install_only" == true ]]; then
        print_success "KubeDiagrams installation completed"
        exit 0
    fi
    
    # Create diagrams directory
    create_diagrams_directory
    
    if [[ "$viewer_only" == true ]]; then
        setup_interactive_viewer
        print_success "Interactive viewer setup completed"
        exit 0
    fi
    
    # Generate diagrams based on environment
    if [[ "$environment" == "all" ]]; then
        generate_all_diagrams
    else
        print_status "Generating diagrams for environment: $environment"
        local yaml_dir=$(generate_helm_templates "$environment")
        generate_diagrams "$yaml_dir" "$environment"
        generate_custom_diagram "$environment"
    fi
    
    # Set up interactive viewer
    setup_interactive_viewer
    
    # Cleanup if requested
    if [[ "$cleanup_flag" == true ]]; then
        cleanup
    fi
    
    print_success "KubeDiagrams integration completed successfully!"
    print_status "Diagrams generated in: $DIAGRAMS_DIR"
    print_status "Interactive viewer: $DIAGRAMS_DIR/interactive-viewer/index.html"
    print_status "To view diagrams, open: $DIAGRAMS_DIR/interactive-viewer/index.html"
}

# Run main function with all arguments
main "$@" 