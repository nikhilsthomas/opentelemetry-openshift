#!/bin/bash

echo "🚀 Quick Deployment Script for OpenShift Distributed Tracing"
echo "============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if user wants to proceed
echo ""
print_warning "This script will deploy distributed tracing with the following:"
echo "  • Cluster Observability Operator"
echo "  • Distributed Tracing UI Plugin"
echo "  • TempoStack with multi-tenancy"
echo "  • OpenTelemetry Collectors (dev/prod)"
echo "  • Sample PetClinic applications"
echo ""
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Check if S3 credentials are configured
echo ""
print_warning "IMPORTANT: Make sure you've updated 04-tempo-storage-secret.yaml with your S3 credentials!"
read -p "Have you updated the S3 storage secret? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Please update 04-tempo-storage-secret.yaml with your S3 credentials first!"
    exit 1
fi

echo ""
echo "🏁 Starting deployment..."

# Step 1: Install Cluster Observability Operator
echo ""
print_status "Step 1: Installing Cluster Observability Operator..."
oc apply -f 01-cluster-observability-operator.yaml
echo "Waiting for operator to be ready..."
sleep 30

# Step 2: Enable UI Plugin
echo ""
print_status "Step 2: Enabling Distributed Tracing UI Plugin..."
oc apply -f 02-distributed-tracing-ui-plugin.yaml

# Step 3: Create namespace
echo ""
print_status "Step 3: Creating Tempo namespace..."
oc apply -f 03-tempo-namespace.yaml

# Step 4: Apply storage secret
echo ""
print_status "Step 4: Applying storage secret..."
oc apply -f 04-tempo-storage-secret.yaml

# Step 5: Deploy TempoStack
echo ""
print_status "Step 5: Deploying TempoStack..."
oc apply -f 05-tempostack.yaml
echo "Waiting for TempoStack to be ready..."
sleep 60

# Step 6: Deploy RBAC
echo ""
print_status "Step 6: Deploying OpenTelemetry RBAC..."
oc apply -f 06-otel-rbac.yaml

# Step 7: Deploy collectors
echo ""
print_status "Step 7: Deploying OpenTelemetry Collectors..."
oc apply -f 07-otel-collectors.yaml
echo "Waiting for collectors to be ready..."
sleep 30

# Step 8: Deploy instrumentation
echo ""
print_status "Step 8: Deploying Instrumentation configurations..."
oc apply -f 08-instrumentation.yaml

# Step 9: Deploy applications
echo ""
print_status "Step 9: Deploying PetClinic applications..."
oc apply -f 09-petclinic-apps.yaml
echo "Waiting for applications to be ready..."
sleep 45

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "📋 Verification commands:"
echo "  oc get tempostack -n tempo"
echo "  oc get opentelemetrycollector -n tempo"
echo "  oc get pods -l app=petclinic"
echo "  oc get UIPlugin distributed-tracing"
echo ""
echo "🌐 Access traces in OpenShift Console:"
echo "  Navigate to: Observe → Traces"
echo ""
echo "🔧 Generate test traffic:"
echo "  oc expose service petclinic-dev -n default"
echo "  curl \$(oc get route petclinic-dev -n default -o jsonpath='{.spec.host}')"
echo ""

# Final verification
echo "🔍 Quick verification..."
if oc get UIPlugin distributed-tracing >/dev/null 2>&1; then
    print_status "UIPlugin is created"
else
    print_error "UIPlugin not found"
fi

if oc get tempostack simple -n tempo >/dev/null 2>&1; then
    print_status "TempoStack is created"
else
    print_error "TempoStack not found"
fi

if oc get pods -l app=petclinic -n default | grep -q Running; then
    print_status "PetClinic applications are running"
else
    print_warning "PetClinic applications may still be starting"
fi

echo ""
print_status "Setup complete! Check the OpenShift Console under Observe → Traces"