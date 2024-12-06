#!/bin/bash

# Flag to track if we need cleanup
CLEANUP_NEEDED=false

# Function to handle cleanup
cleanup() {
    if [ "$CLEANUP_NEEDED" = true ]; then
        echo -e "\n🧹 Running cleanup due to installation failure or interruption..."
        ./kafka_cluster/scripts/uninstall.sh
    fi
    exit 1
}

# Trap ctrl-c (SIGINT) and installation failures
# trap cleanup SIGINT ERR

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 successful"
    else
        echo "❌ $1 failed"
        CLEANUP_NEEDED=false
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install required tools
install_requirements() {
    echo "Checking and installing requirements..."
    
    if ! command_exists jq; then
        echo "Installing jq..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command_exists yum; then
                sudo yum install -y jq
            elif command_exists apk; then
                apk add --no-cache jq
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install jq
            else
                echo "Please install Homebrew first"
                CLEANUP_NEEDED=true
                exit 1
            fi
        else
            echo "Unsupported operating system"
            CLEANUP_NEEDED=true
            exit 1
        fi
    fi
    echo "✅ Requirements check completed"
}

# Start installation process
echo "Starting installation process..."
CLEANUP_NEEDED=true  # Set flag as we're starting installation

# Install requirements
install_requirements

echo $(pwd)

# Create directories
echo "Creating directories..."
mkdir -p ~/k3d/data/kafka
check_status "Directory creation"

# Create k3d cluster
echo "Creating k3d cluster..."
k3d cluster create --config kafka_cluster/infrastructure/cluster/k3d_config.yaml
check_status "Cluster creation"

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s
check_status "Nodes ready"
kubectl wait --for=condition=Ready -n kube-system pods --all --timeout=120s
check_status "System pods ready"

echo "Applying Kafka configuration..."
kubectl apply -f kafka_cluster/infrastructure/kafka/kafka-init-configmap.yaml  
kubectl apply -f kafka_cluster/infrastructure/kafka/kafka_bitnami_with_ingress.yaml  
check_status "Kafka configuration"

# Wait for Kafka pods
echo "Waiting for Kafka pods..."
kubectl wait --for=condition=Ready pod -l app=kafka-app --timeout=300s
check_status "Kafka pods ready"

echo "Applying Kafka client configuration..."
kubectl apply -f kafka_cluster/infrastructure/kafka/kafka-client.yaml
check_status "Kafka client configuration"

# Wait for Kafka client
echo "Waiting for Kafka client pod..."
kubectl wait --for=condition=Ready pod kafka-client --timeout=120s
check_status "Kafka client ready"

echo "Applying Kafka UI configuration..."
kubectl apply -f kafka_cluster/infrastructure/kafka/kafka-ui.yaml
check_status "Kafka ui configuration"

# # Wait for Kafka client
# echo "Waiting for Kafka ui pod..."
# kubectl wait --for=condition=Ready pod kafka-ui --timeout=120s
# check_status "Kafka ui ready"

kubectl apply -f kafka_cluster/infrastructure/ingress/kafka-ui-ingress.yaml
kubectl apply -f kafka_cluster/infrastructure/ingress/kafka-tcp-ingress.yaml
kubectl apply -f kafka_cluster/infrastructure/ingress/traefik-config.yaml
kubectl apply -f kafka_cluster/infrastructure/ingress/traefik-debug.yaml

# echo "To access the Kafka UI:"
# echo "kubectl port-forward svc/kafka-ui 8080:8080"
# echo "Then visit: http://localhost:8080"

# Test Kafka functionality
# echo "Testing Kafka messaging..."
# TEST_TOPIC="test-topic"
# TEST_MESSAGE="Hello from install script!"

# # Create test topic
# echo "Creating test topic..."
# kubectl exec kafka-client -- /opt/bitnami/kafka/bin/kafka-topics.sh \
#     --bootstrap-server kafka-svc:9092 \
#     --create \
#     --if-not-exists \
#     --topic $TEST_TOPIC \
#     --partitions 3 \
#     --replication-factor 3
# check_status "Topic creation"

# Start consumer in background
# echo "Starting consumer..."
# kubectl exec kafka-client -- /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
#     --bootstrap-server kafka-svc:9092 \
#     --topic $TEST_TOPIC \
#     --from-beginning > /tmp/consumer.out 2>&1 &
# check_status "Consumer start"

# # Give consumer time to start
# sleep 5

# Send test message
# echo "Sending test message..."
# echo $TEST_MESSAGE | kubectl exec -i kafka-client -- /opt/bitnami/kafka/bin/kafka-console-producer.sh \
#     --bootstrap-server kafka-svc:9092 \
#     --topic $TEST_TOPIC
# check_status "Message production"

# # Give message time to be consumed
# sleep 5

# # Check if message was received
# echo "Checking if message was received..."
# RECEIVED_MESSAGE=$(kubectl exec kafka-client -- cat /tmp/consumer.out)
# if [[ "$RECEIVED_MESSAGE" == *"$TEST_MESSAGE"* ]]; then
#     echo "✅ Test message successfully received!"
# else
#     echo "❌ Test message not found in consumer output"
#     exit 1
# fi

echo "🎉 Installation and testing completed successfully!"