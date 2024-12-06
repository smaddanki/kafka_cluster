#!/bin/bash
set -e
echo $(pwd)

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 successful"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Function to safely delete resources
safe_delete() {
    resource_type=$1
    resource_name=$2
    namespace=${3:-default}  # Default namespace if not provided

    if kubectl get $resource_type $resource_name -n $namespace &>/dev/null; then
        echo "Deleting $resource_type/$resource_name in namespace $namespace..."
        kubectl delete $resource_type $resource_name -n $namespace
        check_status "$resource_type deletion"
    else
        echo "⏭️  $resource_type/$resource_name not found, skipping..."
    fi
}

echo "Starting cleanup process..."

# Delete Kafka resources
echo "Cleaning up Kafka resources..."
safe_delete pod "kafka-client"
safe_delete pdb "kafka-pdb"
safe_delete statefulset "kafka"
safe_delete service "kafka-svc"

# Delete PVCs
echo "Cleaning up PVCs..."
kubectl get pvc -l app=kafka-app -o name | while read pvc; do
    kubectl delete $pvc
    check_status "PVC deletion"
done

# Delete k3d cluster
echo "Deleting k3d cluster..."
if k3d cluster list | grep -q "kafka-cluster"; then
    k3d cluster delete kafka-cluster
    check_status "Cluster deletion"
else
    echo "⏭️  Cluster not found, skipping..."
fi

# Clean up data directories
echo "Cleaning up data directories..."
rm -rf ~/k3d/data/kafka
rm -rf ~/k3d/data/zookeeper
check_status "Data directory cleanup"

echo "🧹 Cleanup completed successfully!"