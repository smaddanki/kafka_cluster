#!/bin/bash

# Function to print headers
print_header() {
    echo -e "\n=== $1 ===\n"
}

# Function to check component status
check_component_status() {
    local status=$1
    if [ "$status" == "True" ]; then
        echo "✅"
    else
        echo "❌"
    fi
}

# Cluster Node Status
print_header "CLUSTER NODE STATUS"
echo "NODE STATISTICS:"
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
ROLE:.metadata.labels."kubernetes\.io/role",\
AGE:.metadata.creationTimestamp

# Node Capacity and Allocatable Resources
print_header "NODE CAPACITY AND ALLOCATABLE RESOURCES"
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU-CAPACITY:.status.capacity.cpu,\
CPU-ALLOCATABLE:.status.allocatable.cpu,\
MEMORY-CAPACITY:.status.capacity.memory,\
MEMORY-ALLOCATABLE:.status.allocatable.memory,\
PODS-CAPACITY:.status.capacity.pods

# Pod Status across all namespaces
print_header "POD STATUS (ALL NAMESPACES)"
kubectl get pods --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
RESTARTS:.status.containerStatuses[*].restartCount,\
AGE:.metadata.creationTimestamp

# Kafka Specific Status
print_header "KAFKA CLUSTER STATUS"
echo "KAFKA PODS:"
kubectl get pods -l app=kafka-app -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP,\
RESTARTS:.status.containerStatuses[*].restartCount

echo -e "\nKAFKA SERVICES:"
kubectl get svc -l app=kafka-app -o wide

# PVC Status
print_header "PERSISTENT VOLUME CLAIMS STATUS"
kubectl get pvc -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.spec.resources.requests.storage,\
ACCESS-MODES:.spec.accessModes[*]

# Resource Utilization
print_header "RESOURCE UTILIZATION"
echo "TOP NODES BY CPU:"
kubectl top nodes --sort-by=cpu

echo -e "\nTOP NODES BY MEMORY:"
kubectl top nodes --sort-by=memory

echo -e "\nTOP PODS BY CPU:"
kubectl top pods --all-namespaces --sort-by=cpu

echo -e "\nTOP PODS BY MEMORY:"
kubectl top pods --all-namespaces --sort-by=memory

# Events
print_header "RECENT CLUSTER EVENTS"
kubectl get events --sort-by='.lastTimestamp' --all-namespaces | tail -n 10

# Additional Kafka-specific checks
print_header "KAFKA CLUSTER HEALTH CHECK"

# Check if all replicas are ready
DESIRED_REPLICAS=$(kubectl get statefulset kafka -o=jsonpath='{.spec.replicas}')
READY_REPLICAS=$(kubectl get statefulset kafka -o=jsonpath='{.status.readyReplicas}')

echo "Kafka StatefulSet Status:"
echo "Desired Replicas: $DESIRED_REPLICAS"
echo "Ready Replicas: $READY_REPLICAS"

if [ "$DESIRED_REPLICAS" == "$READY_REPLICAS" ]; then
    echo "✅ All Kafka replicas are ready"
else
    echo "❌ Some Kafka replicas are not ready"
fi

# Check Kafka broker connectivity
print_header "KAFKA BROKER CONNECTIVITY TEST"
if kubectl get pod kafka-client &>/dev/null; then
    echo "Testing Kafka broker connectivity..."
    kubectl exec kafka-client -- kafka-topics.sh --bootstrap-server kafka-svc:9092 --list
    if [ $? -eq 0 ]; then
        echo "✅ Successfully connected to Kafka brokers"
    else
        echo "❌ Failed to connect to Kafka brokers"
    fi
else
    echo "⚠️  kafka-client pod not found. Skipping connectivity test."
fi

# Summary of key metrics
print_header "CLUSTER SUMMARY"
echo "Total Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Total Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
echo "Total Services: $(kubectl get svc --all-namespaces --no-headers | wc -l)"
echo "Total PVCs: $(kubectl get pvc --all-namespaces --no-headers | wc -l)"