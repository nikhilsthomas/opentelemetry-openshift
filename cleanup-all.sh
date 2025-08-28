#!/bin/bash

echo "🧹 Comprehensive Cleanup Script for OpenShift Distributed Tracing Setup"
echo "======================================================================="

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    if [ ! -z "$namespace" ]; then
        if oc get $resource_type $resource_name -n $namespace >/dev/null 2>&1; then
            echo "Deleting $resource_type/$resource_name from namespace $namespace..."
            oc delete $resource_type $resource_name -n $namespace
        else
            echo "Resource $resource_type/$resource_name not found in namespace $namespace"
        fi
    else
        if oc get $resource_type $resource_name >/dev/null 2>&1; then
            echo "Deleting cluster-scoped $resource_type/$resource_name..."
            oc delete $resource_type $resource_name
        else
            echo "Cluster-scoped resource $resource_type/$resource_name not found"
        fi
    fi
}

echo ""
echo "1️⃣ Cleaning up UIPlugin resources..."
safe_delete "UIPlugin" "distributed-tracing" ""

echo ""
echo "2️⃣ Cleaning up ConsolePlugin resources..."
safe_delete "ConsolePlugin" "distributed-tracing-console-plugin" ""

echo ""
echo "3️⃣ Cleaning up Console operator configuration..."
oc patch console cluster --type='json' -p='[{"op": "remove", "path": "/spec/plugins"}]' 2>/dev/null || true

echo ""
echo "4️⃣ Cleaning up OpenTelemetry resources..."
# Clean up from multiple possible namespaces
for ns in default observability tempo openshift-tempo-operator; do
    if oc get namespace $ns >/dev/null 2>&1; then
        echo "Checking namespace $ns for OpenTelemetry resources..."
        oc delete OpenTelemetryCollector --all -n $ns 2>/dev/null || true
        oc delete Instrumentation --all -n $ns 2>/dev/null || true
    fi
done

echo ""
echo "5️⃣ Cleaning up TempoStack resources..."
for ns in tempo observability default; do
    if oc get namespace $ns >/dev/null 2>&1; then
        echo "Checking namespace $ns for TempoStack resources..."
        oc delete TempoStack --all -n $ns 2>/dev/null || true
    fi
done

echo ""
echo "6️⃣ Cleaning up application deployments..."
oc delete deployment petclinic petclinic-dev petclinic-prod -n default 2>/dev/null || true
oc delete service petclinic petclinic-dev petclinic-prod -n default 2>/dev/null || true

echo ""
echo "7️⃣ Cleaning up RBAC resources..."
safe_delete "ClusterRole" "tempostack-traces-reader" ""
safe_delete "ClusterRole" "otel-collector" ""
safe_delete "ClusterRoleBinding" "tempostack-traces-reader" ""
safe_delete "ClusterRoleBinding" "otel-collector" ""

echo ""
echo "8️⃣ Cleaning up ServiceAccounts..."
for ns in default observability tempo; do
    if oc get namespace $ns >/dev/null 2>&1; then
        safe_delete "ServiceAccount" "otel-collector" "$ns"
    fi
done

echo ""
echo "9️⃣ Cleaning up ConfigMaps..."
for ns in observability tempo openshift-tempo-operator; do
    if oc get namespace $ns >/dev/null 2>&1; then
        safe_delete "ConfigMap" "tempo-console-config" "$ns"
    fi
done

echo ""
echo "🔟 Cleaning up custom namespaces (be careful!)..."
read -p "Do you want to delete the 'observability' namespace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_delete "namespace" "observability" ""
fi

read -p "Do you want to delete the 'tempo' namespace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_delete "namespace" "tempo" ""
fi

echo ""
echo "1️⃣1️⃣ Optional: Uninstall Cluster Observability Operator..."
read -p "Do you want to uninstall the Cluster Observability Operator? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Cluster Observability Operator subscription..."
    oc delete subscription cluster-observability-operator -n openshift-operators 2>/dev/null || true
    
    echo "Finding and removing CSV..."
    CSV=$(oc get csv -n openshift-operators | grep cluster-observability-operator | awk '{print $1}')
    if [ ! -z "$CSV" ]; then
        oc delete csv $CSV -n openshift-operators
    fi
fi

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "💡 Next steps:"
echo "   1. Wait a few minutes for all resources to be fully deleted"
echo "   2. Run the new installation script"
echo "   3. Verify the setup"
echo ""