# AICMP Platform Deployment Guide

Step-by-step deployment instructions for AICMP on AWS EKS.

## Overview

AICMP is a content management platform that automates content creation, publishing, and analytics. This guide covers deployment in various environments.

## Prerequisites

### Tools Required
- kubectl (v1.24+)
- Helm (v3.8+)
- AWS CLI (v2.0+)
- eksctl (for cluster creation)
- Docker (for diagram generation)
- jq (for JSON processing)
- aws-iam-authenticator
- kubectl-cost (for cost monitoring)

### AWS Services
- EKS Cluster (v1.24+)
- AWS Load Balancer Controller
- EBS CSI Driver
- Prometheus Operator
- Karpenter
- S3 Bucket (for media storage)
- CloudFront (optional, for CDN)

### Permissions
- EKS cluster access
- ECR repository access
- IAM roles for service accounts
- S3 bucket access
- CloudFront distribution access (if using CDN)

## Quick Deployment

### 1. Cluster Setup

```bash
eksctl create cluster \
  --name aicmp-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 10 \
  --managed

aws eks update-kubeconfig --name aicmp-cluster --region us-west-2
```

### 2. Install Prerequisites

```bash
# Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=aicmp-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# EBS CSI Driver
helm install aws-ebs-csi-driver eks/aws-ebs-csi-driver \
  -n kube-system \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=ebs-csi-controller-sa

# Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace

# Karpenter
helm repo add karpenter https://charts.karpenter.sh
helm install karpenter karpenter/karpenter \
  -n karpenter \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT:role/KarpenterNodeRole
```

### 3. AWS IAM Authenticator Setup

```bash
# Setup IAM roles and users
make setup-aws-iam

# Update values with your AWS account ID
make update-aws-values

# Generate kubeconfig
make generate-aws-kubeconfig

# Test authentication
make test-aws-auth
```

### 4. Cost Monitoring Setup

```bash
# Install kubectl-cost
make install-kubectl-cost

# Setup cost monitoring
make setup-cost-monitoring
```

### 5. Deploy AICMP Platform

#### Development Environment
```bash
helm install aicmp ./aicmp-platform -f values-dev.yaml \
  --namespace aicmp-dev \
  --create-namespace
```

#### Staging Environment
```bash
helm install aicmp ./aicmp-platform -f values-staging.yaml \
  --namespace aicmp-staging \
  --create-namespace
```

#### Production Environment
```bash
helm install aicmp ./aicmp-platform -f values-prod.yaml \
  --namespace aicmp-prod \
  --create-namespace
```

## Configuration

### Environment-Specific Values

Three value files for different environments:

- `values-dev.yaml`: Development with relaxed security
- `values-staging.yaml`: Staging with moderate security  
- `values-prod.yaml`: Production with strict security

### Key Configuration Sections

#### Global Settings
```yaml
global:
  environment: "production"
  aws:
    region: "us-west-2"
    accountId: "123456789012"
  imageRegistry: "123456789012.dkr.ecr.us-west-2.amazonaws.com"
```

#### CDN Configuration
```yaml
cdnTier:
  enabled: true
  replicaCount: 3
  resources:
    requests:
      cpu: "150m"
      memory: "192Mi"
    limits:
      cpu: "750m"
      memory: "768Mi"
  ingress:
    enabled: true
    className: "alb"
    annotations:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
```

#### Content Service Configuration
```yaml
contentService:
  enabled: true
  replicaCount: 5
  image:
    repository: "aicmp-platform/content-service"
    tag: "v1.0.0"
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 30
    targetCPUUtilizationPercentage: 60
```

#### Data Tier Configuration
```yaml
dataTier:
  postgresql:
    enabled: true
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
    storage:
      size: "100Gi"
      storageClass: "gp3"
  
  redis:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        cpu: "250m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "2Gi"
    storage:
      size: "20Gi"
      storageClass: "gp3"
```

## Security

### Pod Security Standards

Kubernetes Pod Security Standards at restricted level:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: "RuntimeDefault"
  capabilities:
    drop:
      - "ALL"
```

### Network Policies

Default-deny network policies control pod communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### RBAC Configuration

Service accounts with least-privilege access:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: content-service-sa
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/ContentServiceRole"
```

## Monitoring

### Prometheus Integration

ServiceMonitors collect metrics from all services:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: content-service-monitor
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: "content-service"
  endpoints:
  - port: http
    interval: 30s
```

### Grafana Dashboards

Pre-configured dashboards for application monitoring.

### Alerting Rules

Critical alerts for:
- High CPU/memory usage
- Pod restart frequency
- Service availability
- Database connectivity issues

## Auto-scaling

### Horizontal Pod Autoscaler

CPU and memory-based scaling for all services:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: content-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: content-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Karpenter Node Autoscaling

Automated node provisioning based on pod requirements.

## Backup and Recovery

### Velero Configuration

Automated backups for application data:

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: aicmp-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    includedNamespaces:
    - aicmp-prod
    ttl: "720h"  # 30 days
```

## Troubleshooting

### Common Issues

**Pods stuck in Pending state:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Service connectivity issues:**
```bash
kubectl get endpoints -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Ingress not working:**
```bash
kubectl describe ingress -n <namespace>
kubectl get svc -n <namespace>
```

### Log Analysis

```bash
# View application logs
kubectl logs -f deployment/cdn-tier -n <namespace>

# View multiple containers
kubectl logs -f deployment/content-service -c content-service -n <namespace>

# Export logs for analysis
kubectl logs deployment/cdn-tier -n <namespace> > cdn-tier.log
```

## Performance Optimization

### Resource Tuning

Monitor resource usage and adjust requests/limits:

```bash
# Check resource usage
kubectl top pods -n <namespace>

# Analyze resource efficiency
kubectl cost allocation --window 7d --aggregate pod --show-efficiency
```

### Scaling Recommendations

- Start with conservative resource requests
- Monitor actual usage patterns
- Adjust based on peak load requirements
- Consider spot instances for cost optimization

## Cost Management

### Resource Quotas

Control resource consumption within namespaces:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
```

### Cost Monitoring

Use kubectl-cost for cost analysis:

```bash
# Daily cost allocation
kubectl cost allocation --window 1d --aggregate namespace

# Resource efficiency analysis
kubectl cost allocation --window 7d --aggregate pod --show-efficiency

# Export cost reports
kubectl cost allocation --window 30d --aggregate namespace --format csv > cost-report.csv
```

## Customization

### Adding Custom Services

1. Create new deployment template
2. Add service configuration
3. Update network policies
4. Configure monitoring

### Environment-Specific Overrides

Use values files to customize per environment:

```bash
# Create custom values
helm install aicmp . -f values-prod.yaml -f custom-overrides.yaml

# Use external secrets
helm install aicmp . -f values-prod.yaml --set secrets.external=true
```

## Support

### Documentation

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Community Resources

- [Kubernetes Slack](https://slack.k8s.io/)
- [Helm GitHub](https://github.com/helm/helm)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

### Getting Help

1. Check the troubleshooting section
2. Review logs and events
3. Consult AWS EKS documentation
4. Open an issue in the repository 