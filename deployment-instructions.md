# Multi-Tenant OpenShift Distributed Tracing Setup

This configuration enables traces to appear in the OpenShift UI instead of Jaeger UI, with multi-tenant support for dev and prod environments.

## Prerequisites

1. **OpenShift Cluster**: Version 4.11+ with Cluster Observability Operator
2. **Tempo Operator**: Installed and running
3. **OpenTelemetry Operator**: Installed and running
4. **Storage**: S3-compatible storage configured (secret `tempo-storage`)

## Deployment Steps

### 1. Create the Tempo namespace
```bash
oc create namespace tempo
```

### 2. Deploy the Multi-Tenant TempoStack
```bash
oc apply -f tempostack-multitenant.yaml
```

### 3. Deploy the OpenTelemetry Collectors
```bash
oc apply -f otel-collector-multitenant.yaml
```

### 4. Ensure Cluster Observability Operator is installed
```bash
# Install via OperatorHub in OpenShift Console, or apply:
oc apply -f cluster-observability-setup.yaml

# Verify the distributed tracing console plugin is enabled:
oc get console cluster -o jsonpath='{.spec.plugins}'
```

### 5. Deploy Instrumentation configurations
```bash
oc apply -f instrumentation-multitenant.yaml
```

### 6. Deploy PetClinic applications
```bash
oc apply -f petclinic-deployment-multitenant.yaml
```

## Key Changes from Original Configuration

### 1. Multi-Tenant TempoStack
- **Tenant Mode**: Set to `openshift` for OpenShift integration
- **Authentication**: Configured dev and prod tenants with unique IDs
- **Gateway**: Enabled for multi-tenant routing
- **RBAC**: Added ClusterRole and ClusterRoleBinding for trace access

### Important Note on Multi-Tenancy in OpenShift Console
⚠️ **Current Limitation**: As of 2024, the OpenShift Console Traces UI does not fully support multi-tenancy. While your backend (TempoStack) will properly separate traces by tenant, the OpenShift Console UI may show traces from all tenants together. For true tenant isolation in the UI, you may still need to use the Jaeger Query UI or implement custom dashboards.

### 2. OpenTelemetry Collectors
- **Separate Collectors**: One for dev, one for prod
- **Authentication**: Uses bearer token authentication
- **Headers**: Includes `X-Scope-OrgID` for tenant routing
- **TLS**: Properly configured for secure communication
- **Service Account**: Dedicated service account with proper RBAC

### 3. Instrumentation
- **Environment-Specific**: Separate instrumentation for dev and prod
- **Resource Attributes**: Includes environment and tenant information
- **Tenant Headers**: Properly set for multi-tenancy

### 4. Application Deployments
- **Environment Separation**: Separate deployments for dev and prod
- **Resource Attributes**: Environment-specific service names and attributes
- **Scaling**: Different replica counts for environments

## Accessing Traces in OpenShift Console

1. Navigate to the OpenShift Web Console
2. Go to **Observe** → **Traces**
3. Select the appropriate tenant (dev or prod)
4. View and analyze your application traces

## Tenant Information

- **Dev Tenant**:
  - Name: `dev`
  - ID: `1610b0c3-c509-4592-a256-a1871353dbfa`
  - Collector: `otel-dev-collector`

- **Prod Tenant**:
  - Name: `prod`
  - ID: `1610b0c3-c509-4592-a256-a1871353dbfb`
  - Collector: `otel-prod-collector`

## Verification

1. Check TempoStack status:
```bash
oc get tempostack -n tempo
```

2. Check OpenTelemetry Collectors:
```bash
oc get opentelemetrycollector
```

3. Check application pods:
```bash
oc get pods -l app=petclinic
```

4. Generate some traffic to your applications and check traces in the OpenShift Console under **Observe** → **Traces**.

## Troubleshooting

- Ensure the Cluster Observability Operator is installed and the Traces UI plugin is enabled
- Verify that the storage secret `tempo-storage` exists and is properly configured
- Check that the service accounts have the necessary RBAC permissions
- Confirm that the applications are properly instrumented and sending traces to the correct collectors