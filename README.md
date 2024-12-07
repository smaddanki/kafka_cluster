# Kafka Cluster with KRaft Mode on Kubernetes with Traefik

This project sets up a 3-node Kafka cluster on Kubernetes using KRaft (no ZooKeeper) with external access through Traefik ingress controller.

## Key Highlights
1. **KRaft Mode Implementation**: Multi-broker Kafka cluster using KRaft consensus without ZooKeeper dependency
2. **High Availability**: 3-node Kafka cluster with topology spread constraints and PodDisruptionBudget
3. **Data Persistence**: Persistent storage using local-path provisioner
4. **External Access**: Traefik TCP routing for external Kafka access
5. **Monitoring**: Kafka UI for cluster management and monitoring
6. **Zone Distribution**: Automatic pod distribution across multiple zones for fault tolerance

## Prerequisites
- Docker
- K3d
- kubectl
- Python 3.x
- kcat (kafkacat)

## Quick Start
```bash
# Installation
./k3d_kafka/scripts/install.sh

# Uninstallation
./k3d_kafka/scripts/uninstall.sh

# Check cluster health
./k3d_kafka/scripts/cluster_health.sh
```

## Installation Details
The install script performs:
1. Creates k3d cluster with required configurations
2. Sets up Kafka StatefulSet with 3 replicas
3. Configures Traefik for external access
4. Deploys Kafka UI
5. Verifies cluster health
6. Creates test topics and validates functionality

## Uninstallation Details
The uninstall script:
1. Removes all Kafka resources
2. Cleans up PVCs and volumes
3. Deletes the k3d cluster
4. Removes local data directories

## Health Monitoring
The cluster_health script checks:
1. Node status and distribution
2. Pod health and readiness
3. Kafka broker status
4. Resource utilization
5. Network connectivity
6. Topic replication status

## Architecture

- 3 Kafka brokers running in KRaft mode (no ZooKeeper)
- Traefik TCP ingress for external access
- Persistent storage using PVCs
- Pod anti-affinity for high availability
- Pod disruption budget for controlled updates

### Components

1. **StatefulSet**: Manages the Kafka brokers
2. **Service**: Provides internal and external access
3. **ConfigMap**: Contains initialization scripts
4. **IngressRouteTCP**: Configures Traefik routing
5. **PodDisruptionBudget**: Ensures availability during updates

### Ports

- 29092: Internal broker communication
- 9092: External client access
- 9093: Controller port (KRaft)

## Testing the Cluster

1. List topics:
```bash
kcat -L -b 127.0.0.1:9092
```

2. Create a topic:
```bash
kcat -P -b 127.0.0.1:9092 -t test-topic -p 0
```

3. Produce messages:
```bash
echo "Hello Kafka" | kcat -P -b 127.0.0.1:9092 -t test-topic
```

4. Consume messages:
```bash
kcat -C -b 127.0.0.1:9092 -t test-topic -p 0
```

### Traefik Configuration

TCP routing configuration:
```yaml
entryPoints:
  - kafka
routes:
  - match: HostSNI(`*`)
    services:
      - name: kafka-svc
        port: 9092
```

## Known Limitations

1. Development Setup:
   - Using PLAINTEXT protocol (no security)
   - Limited performance due to local environment
   - Basic resource allocation

2. Production Considerations:
   - Add security (SSL/SASL)
   - Tune performance parameters
   - Configure proper monitoring
   - Implement backup strategy

## Troubleshooting

1. Check pod status:
```bash
kubectl get pods -l app=kafka-app
```

2. View Kafka logs:
```bash
kubectl logs -l app=kafka-app
```

3. Check Traefik routing:
```bash
kubectl get ingressroutetcp
```

4. Verify connectivity:
```bash
kcat -L -b 127.0.0.1:9092 -v
```

## Usage
```python
from kafka import KafkaProducer
producer = KafkaProducer(bootstrap_servers=['localhost:29092'])
producer.send('test-topic', b'test message')
```

## Known Issues
1. Port-forwarding required for local development
2. Initial broker connection sometimes requires retry
3. Node ID extraction complexity in StatefulSet
4. Message order guarantee limitations with multiple brokers

## Future Improvements
1. Implement SSL/TLS security
2. Add metrics collection (Prometheus)
3. Implement automatic scaling
4. Add backup/restore functionality
5. Improve external access without port-forwarding
6. Add multi-cluster support

## Maintenance
Regular health checks:
```bash
./cluster_health.sh
```

## Author
[Sudhamshu Addanki]