# 🔥 COMPLETE OpenShift Distributed Tracing Setup Guide

## 🧹 CLEANUP FIRST (Important!)

**If you have any existing setup, run the cleanup script first:**

```bash
./cleanup-all.sh
```

**Wait 2-3 minutes** for all resources to be completely removed before proceeding.

---

## 📋 Prerequisites

1. **OpenShift Cluster**: Version 4.11+
2. **Cluster Admin Access**: Required for installing operators
3. **S3 Storage**: AWS S3 or S3-compatible storage (MinIO, etc.)
4. **Operators Required**:
   - Red Hat OpenShift distributed tracing data collection Operator
   - Tempo Operator
   - Cluster Observability Operator

---

## 🚀 Step-by-Step Installation

### Step 1: Install Required Operators

**Install these operators via OpenShift Console → OperatorHub:**

1. **Red Hat OpenShift distributed tracing data collection** (for OpenTelemetry)
2. **Tempo Operator** (for Tempo)
3. **Cluster Observability Operator** (for UI integration)

**Or install via CLI:**

```bash
# Install Cluster Observability Operator
oc apply -f 01-cluster-observability-operator.yaml

# Wait for the operator to be ready
oc wait --for=condition=Ready csv -l operators.coreos.com/cluster-observability-operator.openshift-operators -n openshift-operators --timeout=300s
```

### Step 2: Enable Distributed Tracing UI Plugin

```bash
# Create the UI Plugin
oc apply -f 02-distributed-tracing-ui-plugin.yaml

# Verify the plugin is created
oc get UIPlugin distributed-tracing
```

### Step 3: Create Tempo Namespace

```bash
oc apply -f 03-tempo-namespace.yaml
```

### Step 4: Configure S3 Storage

**⚠️ IMPORTANT: Edit the storage secret with your actual S3 credentials:**

```bash
# Edit the file with your S3 details
vi 04-tempo-storage-secret.yaml

# Apply the secret
oc apply -f 04-tempo-storage-secret.yaml
```

### Step 5: Deploy TempoStack

```bash
oc apply -f 05-tempostack.yaml

# Wait for TempoStack to be ready
oc wait --for=condition=Ready tempostack simple -n tempo --timeout=300s
```

### Step 6: Deploy OpenTelemetry RBAC

```bash
oc apply -f 06-otel-rbac.yaml
```

### Step 7: Deploy OpenTelemetry Collectors

```bash
oc apply -f 07-otel-collectors.yaml

# Verify collectors are running
oc get pods -n tempo -l app.kubernetes.io/component=opentelemetry-collector
```

### Step 8: Deploy Instrumentation

```bash
oc apply -f 08-instrumentation.yaml

# Verify instrumentation
oc get instrumentation -n default
```

### Step 9: Deploy Test Applications

```bash
oc apply -f 09-petclinic-apps.yaml

# Wait for deployments to be ready
oc wait --for=condition=Available deployment/petclinic-dev deployment/petclinic-prod -n default --timeout=300s
```

---

## 🔍 Verification Steps

### 1. Check All Components

```bash
# Check TempoStack
oc get tempostack -n tempo

# Check OpenTelemetry Collectors
oc get opentelemetrycollector -n tempo

# Check Applications
oc get pods -l app=petclinic

# Check UIPlugin
oc get UIPlugin distributed-tracing
```

### 2. Generate Test Traffic

```bash
# Create routes for your applications (optional)
oc expose service petclinic-dev -n default
oc expose service petclinic-prod -n default

# Get route URLs
oc get routes -n default

# Generate some traffic
curl $(oc get route petclinic-dev -n default -o jsonpath='{.spec.host}')
curl $(oc get route petclinic-prod -n default -o jsonpath='{.spec.host}')
```

### 3. Access Traces in OpenShift Console

1. **Navigate to OpenShift Web Console**
2. **Go to: Observe → Traces**
3. **You should see the distributed tracing UI**
4. **Select traces and analyze them**

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PetClinic     │    │  OpenTelemetry   │    │   TempoStack    │
│   Apps          │───▶│  Collectors      │───▶│   (Multi-tenant)│
│   (default ns)  │    │  (tempo ns)      │    │   (tempo ns)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                          │
                                                          ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  OpenShift      │◀───│  Cluster         │    │   S3 Storage    │
│  Console UI     │    │  Observability   │    │                 │
│  (Traces)       │    │  Operator        │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Component Details:

- **Namespace Strategy**: All tracing infrastructure in `tempo` namespace, apps in `default`
- **Multi-Tenancy**: Dev and Prod tenants with separate collectors
- **Security**: Bearer token authentication + TLS
- **Storage**: S3-compatible backend
- **UI Integration**: Native OpenShift Console integration

---

## 🐛 Troubleshooting

### UI Not Showing Up?

```bash
# Check if UIPlugin exists
oc get UIPlugin distributed-tracing

# Check Cluster Observability Operator status
oc get csv -n openshift-operators | grep cluster-observability

# Check console operator logs
oc logs -n openshift-console-operator -l app=console-operator

# Force refresh browser cache (Ctrl+F5)
```

### No Traces Appearing?

```bash
# Check TempoStack status
oc describe tempostack simple -n tempo

# Check collector logs
oc logs -n tempo -l app.kubernetes.io/component=opentelemetry-collector

# Check application instrumentation
oc describe pod -l app=petclinic -n default

# Verify network connectivity
oc exec -n default deployment/petclinic-dev -- nslookup otel-dev-collector.tempo.svc.cluster.local
```

### Storage Issues?

```bash
# Check storage secret
oc get secret tempo-storage -n tempo -o yaml

# Check TempoStack events
oc get events -n tempo | grep TempoStack

# Verify S3 connectivity
```

---

## 🔧 Key Configuration Points

### 1. Tenant IDs
- **Dev**: `1610b0c3-c509-4592-a256-a1871353dbfa`
- **Prod**: `1610b0c3-c509-4592-a256-a1871353dbfb`

### 2. Service Endpoints
- **Tempo Gateway**: `tempo-simple-gateway.tempo.svc.cluster.local:8090`
- **Dev Collector**: `otel-dev-collector.tempo.svc.cluster.local:4317`
- **Prod Collector**: `otel-prod-collector.tempo.svc.cluster.local:4317`

### 3. Important Notes
- ⚠️ **Multi-tenancy limitation**: OpenShift Console UI may show all traces together (backend separation works)
- 🔒 **Security**: All components use TLS and bearer token authentication
- 📊 **Scaling**: Prod environment has 2 replicas, dev has 1

---

## 📚 Additional Resources

- [OpenShift Distributed Tracing Documentation](https://docs.openshift.com/container-platform/latest/distr_tracing/distr_tracing_install/distr-tracing-installing.html)
- [Tempo Operator Documentation](https://grafana.com/docs/tempo/latest/setup/operator/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

---

## 🎯 Success Criteria

✅ **You should see:**
1. "Traces" option under "Observe" in OpenShift Console
2. Distributed tracing UI loads without errors
3. Traces from both dev and prod applications
4. Proper trace attributes (environment, service name, etc.)

If you see all of the above, your setup is working correctly! 🎉