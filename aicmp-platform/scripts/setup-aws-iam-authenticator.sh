#!/bin/bash

# =============================================================================
# AWS IAM AUTHENTICATOR SETUP SCRIPT
# =============================================================================
# This script helps set up AWS IAM Authenticator for EKS cluster authentication.
# It creates necessary IAM roles, policies, and configurations for secure
# Kubernetes access using AWS IAM credentials.

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
CLUSTER_NAME="microservices-cluster"
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID=""

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
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is required but not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "Using AWS Account ID: $AWS_ACCOUNT_ID"
    
    print_success "All prerequisites are satisfied"
}

# Function to create IAM roles for different user types
create_iam_roles() {
    print_status "Creating IAM roles for AWS IAM Authenticator..."
    
    # Create admin role
    print_status "Creating EKS Cluster Admin Role..."
    aws iam create-role \
        --role-name EKSClusterAdminRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::'"$AWS_ACCOUNT_ID"':oidc-provider/oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*:sub": "system:serviceaccount:kube-system:aws-iam-authenticator"
                        }
                    }
                }
            ]
        }' || print_warning "Role EKSClusterAdminRole may already exist"
    
    # Attach admin policy
    aws iam attach-role-policy \
        --role-name EKSClusterAdminRole \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess || true
    
    # Create developer role
    print_status "Creating EKS Developer Role..."
    aws iam create-role \
        --role-name EKSDeveloperRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::'"$AWS_ACCOUNT_ID"':oidc-provider/oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*:sub": "system:serviceaccount:kube-system:aws-iam-authenticator"
                        }
                    }
                }
            ]
        }' || print_warning "Role EKSDeveloperRole may already exist"
    
    # Create developer policy
    aws iam create-policy \
        --policy-name EKSDeveloperPolicy \
        --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "eks:DescribeCluster",
                        "eks:ListClusters",
                        "eks:AccessKubernetesApi"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "ecr:GetAuthorizationToken",
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:GetDownloadUrlForLayer",
                        "ecr:BatchGetImage"
                    ],
                    "Resource": "*"
                }
            ]
        }' || print_warning "Policy EKSDeveloperPolicy may already exist"
    
    # Attach developer policy
    aws iam attach-role-policy \
        --role-name EKSDeveloperRole \
        --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/EKSDeveloperPolicy || true
    
    # Create CI/CD role
    print_status "Creating EKS CI/CD Role..."
    aws iam create-role \
        --role-name EKSCICDRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::'"$AWS_ACCOUNT_ID"':oidc-provider/oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*:sub": "system:serviceaccount:kube-system:aws-iam-authenticator"
                        }
                    }
                }
            ]
        }' || print_warning "Role EKSCICDRole may already exist"
    
    # Create CI/CD policy
    aws iam create-policy \
        --policy-name EKSCICDPolicy \
        --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "eks:DescribeCluster",
                        "eks:ListClusters",
                        "eks:AccessKubernetesApi"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "ecr:GetAuthorizationToken",
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:GetDownloadUrlForLayer",
                        "ecr:BatchGetImage",
                        "ecr:PutImage",
                        "ecr:InitiateLayerUpload",
                        "ecr:UploadLayerPart",
                        "ecr:CompleteLayerUpload"
                    ],
                    "Resource": "*"
                }
            ]
        }' || print_warning "Policy EKSCICDPolicy may already exist"
    
    # Attach CI/CD policy
    aws iam attach-role-policy \
        --role-name EKSCICDRole \
        --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/EKSCICDPolicy || true
    
    # Create read-only role
    print_status "Creating EKS Read-Only Role..."
    aws iam create-role \
        --role-name EKSReadOnlyRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::'"$AWS_ACCOUNT_ID"':oidc-provider/oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*:sub": "system:serviceaccount:kube-system:aws-iam-authenticator"
                        }
                    }
                }
            ]
        }' || print_warning "Role EKSReadOnlyRole may already exist"
    
    # Create read-only policy
    aws iam create-policy \
        --policy-name EKSReadOnlyPolicy \
        --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "eks:DescribeCluster",
                        "eks:ListClusters"
                    ],
                    "Resource": "*"
                }
            ]
        }' || print_warning "Policy EKSReadOnlyPolicy may already exist"
    
    # Attach read-only policy
    aws iam attach-role-policy \
        --role-name EKSReadOnlyRole \
        --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/EKSReadOnlyPolicy || true
    
    print_success "IAM roles created successfully"
}

# Function to create IAM users
create_iam_users() {
    print_status "Creating IAM users for AWS IAM Authenticator..."
    
    # Create admin user
    print_status "Creating admin user..."
    aws iam create-user --user-name admin-user || print_warning "User admin-user may already exist"
    
    # Create developer user
    print_status "Creating developer user..."
    aws iam create-user --user-name developer-user || print_warning "User developer-user may already exist"
    
    # Attach policies to users
    aws iam attach-user-policy \
        --user-name admin-user \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess || true
    
    aws iam attach-user-policy \
        --user-name developer-user \
        --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/EKSDeveloperPolicy || true
    
    print_success "IAM users created successfully"
}

# Function to create AWS IAM Authenticator service account role
create_authenticator_role() {
    print_status "Creating AWS IAM Authenticator service account role..."
    
    aws iam create-role \
        --role-name AWSIAMAuthenticatorRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::'"$AWS_ACCOUNT_ID"':oidc-provider/oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.'"$AWS_REGION"'.amazonaws.com/id/*:sub": "system:serviceaccount:microservices-app:aws-iam-authenticator"
                        }
                    }
                }
            ]
        }' || print_warning "Role AWSIAMAuthenticatorRole may already exist"
    
    # Create authenticator policy
    aws iam create-policy \
        --policy-name AWSIAMAuthenticatorPolicy \
        --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "iam:GetUser",
                        "iam:GetRole",
                        "iam:ListAttachedRolePolicies",
                        "iam:ListRolePolicies",
                        "iam:GetRolePolicy",
                        "iam:GetPolicy",
                        "iam:GetPolicyVersion",
                        "iam:ListPolicyVersions"
                    ],
                    "Resource": "*"
                }
            ]
        }' || print_warning "Policy AWSIAMAuthenticatorPolicy may already exist"
    
    # Attach authenticator policy
    aws iam attach-role-policy \
        --role-name AWSIAMAuthenticatorRole \
        --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/AWSIAMAuthenticatorPolicy || true
    
    print_success "AWS IAM Authenticator role created successfully"
}

# Function to update values.yaml with correct AWS account ID
update_values() {
    print_status "Updating values.yaml with correct AWS account ID..."
    
    local values_file="${CHART_DIR}/values.yaml"
    local temp_file="${values_file}.tmp"
    
    # Update AWS account ID in values.yaml
    sed "s/123456789012/$AWS_ACCOUNT_ID/g" "$values_file" > "$temp_file"
    mv "$temp_file" "$values_file"
    
    print_success "Updated values.yaml with AWS Account ID: $AWS_ACCOUNT_ID"
}

# Function to generate kubeconfig for AWS IAM Authenticator
generate_kubeconfig() {
    print_status "Generating kubeconfig for AWS IAM Authenticator..."
    
    local cluster_endpoint=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.endpoint' --output text 2>/dev/null || echo "")
    
    if [[ -z "$cluster_endpoint" ]]; then
        print_warning "Could not retrieve cluster endpoint. Please ensure the EKS cluster exists."
        return 0
    fi
    
    local cert_data=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.certificateAuthority.data' --output text)
    
    # Create kubeconfig template
    cat > "${CHART_DIR}/kubeconfig-aws-iam-authenticator.yaml" << EOF
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster:
    server: $cluster_endpoint
    certificate-authority-data: $cert_data
contexts:
- name: aws-iam-authenticator@$CLUSTER_NAME
  context:
    cluster: $CLUSTER_NAME
    user: aws-iam-authenticator
current-context: aws-iam-authenticator@$CLUSTER_NAME
users:
- name: aws-iam-authenticator
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "$CLUSTER_NAME"
        - "-r"
        - "arn:aws:iam::$AWS_ACCOUNT_ID:role/EKSClusterAdminRole"
EOF
    
    print_success "Generated kubeconfig: ${CHART_DIR}/kubeconfig-aws-iam-authenticator.yaml"
}

# Function to create Kubernetes RBAC for different user groups
create_kubernetes_rbac() {
    print_status "Creating Kubernetes RBAC for user groups..."
    
    # Create developers group
    kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developers-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-binding
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: developers-role
  apiGroup: rbac.authorization.k8s.io
EOF
    
    # Create CI/CD group
    kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cicd-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cicd-binding
subjects:
- kind: Group
  name: cicd
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cicd-role
  apiGroup: rbac.authorization.k8s.io
EOF
    
    # Create read-only group
    kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-binding
subjects:
- kind: Group
  name: readonly
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
EOF
    
    print_success "Kubernetes RBAC created successfully"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Set up AWS IAM Authenticator for EKS cluster authentication.

OPTIONS:
    -h, --help              Show this help message
    -c, --cluster NAME      EKS cluster name (default: microservices-cluster)
    -r, --region REGION     AWS region (default: us-west-2)
    --skip-iam              Skip IAM role/user creation
    --skip-rbac             Skip Kubernetes RBAC creation
    --update-values         Update values.yaml with AWS account ID
    --generate-kubeconfig   Generate kubeconfig for AWS IAM Authenticator

EXAMPLES:
    $0                      Full setup with default settings
    $0 -c my-cluster        Setup for specific cluster
    $0 --skip-iam           Skip IAM creation (roles already exist)
    $0 --update-values      Only update values.yaml

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - kubectl configured to access the EKS cluster
    - jq installed for JSON processing
    - EKS cluster must exist and be accessible

OUTPUT:
    - IAM roles and policies for different user types
    - IAM users for authentication
    - Kubernetes RBAC for user groups
    - Updated values.yaml with correct AWS account ID
    - Kubeconfig for AWS IAM Authenticator
EOF
}

# Main function
main() {
    local cluster_name="$CLUSTER_NAME"
    local aws_region="$AWS_REGION"
    local skip_iam=false
    local skip_rbac=false
    local update_values_only=false
    local generate_kubeconfig_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--cluster)
                cluster_name="$2"
                shift 2
                ;;
            -r|--region)
                aws_region="$2"
                shift 2
                ;;
            --skip-iam)
                skip_iam=true
                shift
                ;;
            --skip-rbac)
                skip_rbac=true
                shift
                ;;
            --update-values)
                update_values_only=true
                shift
                ;;
            --generate-kubeconfig)
                generate_kubeconfig_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Update global variables
    CLUSTER_NAME="$cluster_name"
    AWS_REGION="$aws_region"
    
    print_status "Starting AWS IAM Authenticator setup..."
    print_status "Cluster: $CLUSTER_NAME"
    print_status "Region: $AWS_REGION"
    
    # Check prerequisites
    check_prerequisites
    
    if [[ "$update_values_only" == true ]]; then
        update_values
        exit 0
    fi
    
    if [[ "$generate_kubeconfig_only" == true ]]; then
        generate_kubeconfig
        exit 0
    fi
    
    # Create IAM resources
    if [[ "$skip_iam" == false ]]; then
        create_iam_roles
        create_iam_users
        create_authenticator_role
    else
        print_warning "Skipping IAM creation"
    fi
    
    # Update values.yaml
    update_values
    
    # Generate kubeconfig
    generate_kubeconfig
    
    # Create Kubernetes RBAC
    if [[ "$skip_rbac" == false ]]; then
        create_kubernetes_rbac
    else
        print_warning "Skipping Kubernetes RBAC creation"
    fi
    
    print_success "AWS IAM Authenticator setup completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Deploy the Helm chart: helm install myapp . -f values.yaml"
    print_status "2. Test authentication: kubectl --kubeconfig kubeconfig-aws-iam-authenticator.yaml get pods"
    print_status "3. Configure your IDE/CI/CD to use the generated kubeconfig"
    print_status ""
    print_status "For more information, see the README.md file."
}

# Run main function with all arguments
main "$@" 