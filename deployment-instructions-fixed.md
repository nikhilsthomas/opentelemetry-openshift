# Multi-Tenant OpenShift Distributed Tracing Setup - Fixed Namespace Configuration

This configuration enables traces to appear in the OpenShift UI instead of Jaeger UI, with multi-tenant support for dev and prod environments.

## Prerequisites

1. **OpenShift Cluster**: Version 4.11+ with Cluster Observability Operator
2. **Tempo Operator**: Installed and running
3. **OpenTelemetry Operator**: Installed and running
4. **Storage**: S3-compatible storage configured (secret `tempo-storage`)

## Namespace Strategy

**Fixed namespace organization:**
- **Observability Components**: `observability` namespace (TempoStack, OpenTelemetry Collectors)
- **Applications**: `default` namespace (PetClinic apps, Instrumentation)
- **Cross-namespace communication**: Properly configured with FQDN service names

## Deployment Steps

### 1. Deploy the Multi-Tenant TempoStack (creates observability namespace)
```bash
oc apply -f tempostack-multitenant-fixed.yaml
```

### 2. Create the S3 storage secret in the observability namespace
```bash
# Create the storage secret in the same namespace as TempoStack
oc create secret generic tempo-storage \
  --from-literal=bucket="your-tempo-bucket" \
  --from-literal=endpoint="https://s3.amazonaws.com" \
  --from-literal=access_key_id="your-access-key" \
  --from-literal=access_key_secret="your-secret-key" \
  --from-literal=region="us-east-1" \
  -n observability
```

### 3. Deploy the OpenTelemetry Collectors
```bash
oc apply -f otel-collector-multitenant-fixed.yaml
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
oc apply -f instrumentation-multitenant-fixed.yaml
```

### 6. Deploy PetClinic applications
```bash
oc apply -f petclinic-deployment-multitenant.yaml
```

## Key Fixes Applied

### ✅ **Namespace Consistency:**
- **TempoStack**: `observability` namespace
- **OpenTelemetry Collectors**: `observability` namespace  
- **ServiceAccount**: `observability` namespace
- **Applications**: `default` namespace
- **Storage Secret**: `observability` namespace (same as TempoStack)

### ✅ **Service Communication:**
- **Tempo Gateway Endpoint**: `tempo-multitenant-gateway.observability.svc.cluster.local:8090`
- **OpenTelemetry Collector Endpoints**: 
  - Dev: `otel-dev-collector.observability.svc.cluster.local:4317`
  - Prod: `otel-prod-collector.observability.svc.cluster.local:4317`

### ✅ **RBAC Alignment:**
- ServiceAccount in `observability` namespace
- ClusterRoleBinding references correct namespace
- Cross-namespace permissions properly configured

## Service Discovery and Communication Flow

```
[PetClinic Apps - default namespace] 
    ↓ (instrumentation points to)
[OpenTelemetry Collectors - observability namespace]
    ↓ (collectors send to)
[Tempo Gateway - observability namespace]
    ↓ (stores in)
[S3 Storage]
```

## Verification Commands

1. **Check TempoStack status:**
```bash
oc get tempostack -n observability
```

2. **Check OpenTelemetry Collectors:**
```bash
oc get opentelemetrycollector -n observability
```

3. **Check cross-namespace service resolution:**
```bash
# From default namespace, verify you can resolve observability services
oc run test-pod --image=busybox --rm -it --restart=Never -- nslookup otel-dev-collector.observability.svc.cluster.local
```

4. **Check application pods:**
```bash
oc get pods -l app=petclinic
```

## Tenant Information

- **Dev Tenant**:
  - Name: `dev`
  - ID: `1610b0c3-c509-4592-a256-a1871353dbfa`
  - Collector: `otel-dev-collector.observability.svc.cluster.local:4317`

- **Prod Tenant**:
  - Name: `prod`
  - ID: `1610b0c3-c509-4592-a256-a1871353dbfb`
  - Collector: `otel-prod-collector.observability.svc.cluster.local:4317`

## Accessing Traces in OpenShift Console

1. Navigate to the OpenShift Web Console
2. Go to **Observe** → **Traces**
3. View traces from both environments (note: UI doesn't separate by tenant)

### Important Note on Multi-Tenancy in OpenShift Console
⚠️ **Current Limitation**: The OpenShift Console Traces UI does not fully support multi-tenancy display. While your backend properly separates traces by tenant, the console UI may show traces from all tenants together.

## Troubleshooting

- **Storage Secret**: Ensure `tempo-storage` secret exists in `observability` namespace
- **Network Policies**: Verify cross-namespace communication is allowed
- **DNS Resolution**: Test service discovery between namespaces
- **RBAC**: Confirm ServiceAccount has necessary permissions