# =============================================================================
# MICROSERVICES APPLICATION TEST SUITE
# =============================================================================
# This test file validates the microservices application deployment
# using the Terraform test framework

# Test variables
variables {
  chart_path = "../"
  namespace  = "microservices-test"
  release_name = "test-app"
}

# Test setup - install the chart
run "setup" {
  command = plan

  module {
    source = var.chart_path
  }

  variables {
    namespace = var.namespace
    release_name = var.release_name
  }
}

# Test 1: Verify chart installation
run "test_chart_installation" {
  command = plan

  assert {
    condition     = helm_release.microservices_app.name == var.release_name
    error_message = "Chart name should match release name"
  }

  assert {
    condition     = helm_release.microservices_app.namespace == var.namespace
    error_message = "Chart should be installed in the correct namespace"
  }
}

# Test 2: Verify web tier deployment
run "test_web_tier" {
  command = plan

  assert {
    condition     = kubernetes_deployment.web_tier.metadata[0].name == "${var.release_name}-web-tier"
    error_message = "Web tier deployment should have correct name"
  }

  assert {
    condition     = kubernetes_deployment.web_tier.spec[0].replicas == 2
    error_message = "Web tier should have 2 replicas by default"
  }

  assert {
    condition     = kubernetes_deployment.web_tier.spec[0].template[0].spec[0].container[0].image == "nginx:1.25-alpine"
    error_message = "Web tier should use correct NGINX image"
  }
}

# Test 3: Verify application tier deployment
run "test_app_tier" {
  command = plan

  assert {
    condition     = kubernetes_deployment.app_tier.metadata[0].name == "${var.release_name}-app-tier"
    error_message = "App tier deployment should have correct name"
  }

  assert {
    condition     = kubernetes_deployment.app_tier.spec[0].replicas == 3
    error_message = "App tier should have 3 replicas by default"
  }

  assert {
    condition     = length(kubernetes_deployment.app_tier.spec[0].template[0].spec[0].container[0].env) > 0
    error_message = "App tier should have environment variables configured"
  }
}

# Test 4: Verify data tier deployments
run "test_data_tier" {
  command = plan

  assert {
    condition     = kubernetes_deployment.postgresql.metadata[0].name == "${var.release_name}-postgresql"
    error_message = "PostgreSQL deployment should have correct name"
  }

  assert {
    condition     = kubernetes_deployment.redis.metadata[0].name == "${var.release_name}-redis"
    error_message = "Redis deployment should have correct name"
  }

  assert {
    condition     = kubernetes_deployment.postgresql.spec[0].replicas == 1
    error_message = "PostgreSQL should have 1 replica by default"
  }

  assert {
    condition     = kubernetes_deployment.redis.spec[0].replicas == 2
    error_message = "Redis should have 2 replicas by default"
  }
}

# Test 5: Verify services
run "test_services" {
  command = plan

  assert {
    condition     = kubernetes_service.web_tier.metadata[0].name == "${var.release_name}-web-tier"
    error_message = "Web tier service should have correct name"
  }

  assert {
    condition     = kubernetes_service.app_tier.metadata[0].name == "${var.release_name}-app-tier"
    error_message = "App tier service should have correct name"
  }

  assert {
    condition     = kubernetes_service.postgresql.metadata[0].name == "${var.release_name}-postgresql"
    error_message = "PostgreSQL service should have correct name"
  }

  assert {
    condition     = kubernetes_service.redis.metadata[0].name == "${var.release_name}-redis"
    error_message = "Redis service should have correct name"
  }
}

# Test 6: Verify ingress configuration
run "test_ingress" {
  command = plan

  assert {
    condition     = kubernetes_ingress_v1.web_tier.metadata[0].name == "${var.release_name}-web-tier"
    error_message = "Ingress should have correct name"
  }

  assert {
    condition     = kubernetes_ingress_v1.web_tier.spec[0].ingress_class_name == "alb"
    error_message = "Ingress should use ALB class"
  }
}

# Test 7: Verify secrets
run "test_secrets" {
  command = plan

  assert {
    condition     = kubernetes_secret.database.metadata[0].name == "${var.release_name}-database-secret"
    error_message = "Database secret should have correct name"
  }

  assert {
    condition     = kubernetes_secret.redis.metadata[0].name == "${var.release_name}-redis-secret"
    error_message = "Redis secret should have correct name"
  }

  assert {
    condition     = kubernetes_secret.jwt.metadata[0].name == "${var.release_name}-jwt-secret"
    error_message = "JWT secret should have correct name"
  }
}

# Test 8: Verify RBAC configuration
run "test_rbac" {
  command = plan

  assert {
    condition     = kubernetes_service_account.web_tier.metadata[0].name == "${var.release_name}-web-tier-sa"
    error_message = "Web tier service account should have correct name"
  }

  assert {
    condition     = kubernetes_service_account.app_tier.metadata[0].name == "${var.release_name}-app-tier-sa"
    error_message = "App tier service account should have correct name"
  }

  assert {
    condition     = kubernetes_service_account.data_tier.metadata[0].name == "${var.release_name}-data-tier-sa"
    error_message = "Data tier service account should have correct name"
  }
}

# Test 9: Verify network policies
run "test_network_policies" {
  command = plan

  assert {
    condition     = kubernetes_network_policy_v1.web_tier.metadata[0].name == "${var.release_name}-web-tier-policy"
    error_message = "Web tier network policy should have correct name"
  }

  assert {
    condition     = kubernetes_network_policy_v1.app_tier.metadata[0].name == "${var.release_name}-app-tier-policy"
    error_message = "App tier network policy should have correct name"
  }

  assert {
    condition     = kubernetes_network_policy_v1.data_tier.metadata[0].name == "${var.release_name}-data-tier-policy"
    error_message = "Data tier network policy should have correct name"
  }
}

# Test 10: Verify horizontal pod autoscalers
run "test_hpa" {
  command = plan

  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.web_tier.metadata[0].name == "${var.release_name}-web-tier"
    error_message = "Web tier HPA should have correct name"
  }

  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app_tier.metadata[0].name == "${var.release_name}-app-tier"
    error_message = "App tier HPA should have correct name"
  }

  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.web_tier.spec[0].min_replicas == 2
    error_message = "Web tier HPA should have minimum 2 replicas"
  }

  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.web_tier.spec[0].max_replicas == 10
    error_message = "Web tier HPA should have maximum 10 replicas"
  }
}

# Test 11: Verify pod disruption budgets
run "test_pdb" {
  command = plan

  assert {
    condition     = kubernetes_pod_disruption_budget_v1.web_tier.metadata[0].name == "${var.release_name}-web-tier"
    error_message = "Web tier PDB should have correct name"
  }

  assert {
    condition     = kubernetes_pod_disruption_budget_v1.app_tier.metadata[0].name == "${var.release_name}-app-tier"
    error_message = "App tier PDB should have correct name"
  }
}

# Test 12: Verify persistent volume claims
run "test_pvc" {
  command = plan

  assert {
    condition     = kubernetes_persistent_volume_claim_v1.postgresql.metadata[0].name == "${var.release_name}-postgresql-pvc"
    error_message = "PostgreSQL PVC should have correct name"
  }

  assert {
    condition     = kubernetes_persistent_volume_claim_v1.redis.metadata[0].name == "${var.release_name}-redis-pvc"
    error_message = "Redis PVC should have correct name"
  }

  assert {
    condition     = kubernetes_persistent_volume_claim_v1.postgresql.spec[0].resources[0].requests.storage == "100Gi"
    error_message = "PostgreSQL PVC should request 100Gi storage"
  }

  assert {
    condition     = kubernetes_persistent_volume_claim_v1.redis.spec[0].resources[0].requests.storage == "20Gi"
    error_message = "Redis PVC should request 20Gi storage"
  }
}

# Test 13: Verify monitoring configuration
run "test_monitoring" {
  command = plan

  assert {
    condition     = kubernetes_manifest.service_monitor_web_tier.metadata.name == "${var.release_name}-web-tier-monitor"
    error_message = "Web tier ServiceMonitor should have correct name"
  }

  assert {
    condition     = kubernetes_manifest.service_monitor_app_tier.metadata.name == "${var.release_name}-app-tier-monitor"
    error_message = "App tier ServiceMonitor should have correct name"
  }

  assert {
    condition     = kubernetes_manifest.prometheus_rule.metadata.name == "${var.release_name}-alerts"
    error_message = "PrometheusRule should have correct name"
  }
}

# Test 14: Verify resource quotas and limits
run "test_resource_management" {
  command = plan

  assert {
    condition     = kubernetes_resource_quota_v1.resource_quota.metadata[0].name == "${var.release_name}-resource-quota"
    error_message = "Resource quota should have correct name"
  }

  assert {
    condition     = kubernetes_limit_range_v1.limit_range.metadata[0].name == "${var.release_name}-limit-range"
    error_message = "Limit range should have correct name"
  }
}

# Test 15: Verify backup configuration
run "test_backup" {
  command = plan

  assert {
    condition     = kubernetes_manifest.velero_backup_schedule.metadata.name == "${var.release_name}-backup-schedule"
    error_message = "Velero backup schedule should have correct name"
  }

  assert {
    condition     = kubernetes_manifest.velero_database_backup_schedule.metadata.name == "${var.release_name}-database-backup-schedule"
    error_message = "Database backup schedule should have correct name"
  }
}

# Test cleanup - uninstall the chart
run "cleanup" {
  command = destroy

  module {
    source = var.chart_path
  }

  variables {
    namespace = var.namespace
    release_name = var.release_name
  }
} 