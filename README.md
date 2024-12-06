## Requirements to mitigate common failures
1. A minimum in-sync replicas of 2.
2. A replication factor of 3 for topics.
3. At least 3 Kafka brokers, each running on different nodes.
4. Nodes spread across three availability zones.
Since this implementation uses Kafka Fraft so there is no need of integrating with zookeeper.

## Setup the Cluster

Let's create a three-node cluster that spans three availability zones with:
```bash
k3d cluster create kafka-cluster \
  --agents 3 \
  --k3s-node-label topology.kubernetes.io/zone=zone-a@agent:0 \
  --k3s-node-label topology.kubernetes.io/zone=zone-b@agent:1 \
  --k3s-node-label topology.kubernetes.io/zone=zone-c@agent:2
```


```shell
(3.12.7) ➜  k3d-kafka ./kafka_cluster/scripts/install.sh  
/Users/sudhamshuaddanki/smaddanki/Repos/k3d-kafka
Creating k3d cluster...
INFO[0005] Prep: Network                                
INFO[0005] Created network 'k3d-kafka-cluster'          
INFO[0005] Created image volume k3d-kafka-cluster-images 
INFO[0005] Starting new tools node...                   
INFO[0005] Starting node 'k3d-kafka-cluster-tools'      
INFO[0006] Creating node 'k3d-kafka-cluster-server-0'   
INFO[0006] Creating node 'k3d-kafka-cluster-agent-0'    
INFO[0006] Creating node 'k3d-kafka-cluster-agent-1'    
INFO[0007] Creating node 'k3d-kafka-cluster-agent-2'    
INFO[0007] Creating LoadBalancer 'k3d-kafka-cluster-serverlb' 
INFO[0008] Using the k3d-tools node to gather environment information 
INFO[0009] Starting new tools node...                   
INFO[0009] Starting node 'k3d-kafka-cluster-tools'      
INFO[0011] Starting cluster 'kafka-cluster'             
INFO[0011] Starting servers...                          
INFO[0012] Starting node 'k3d-kafka-cluster-server-0'   
INFO[0018] Starting agents...                           
INFO[0019] Starting node 'k3d-kafka-cluster-agent-2'    
INFO[0019] Starting node 'k3d-kafka-cluster-agent-0'    
INFO[0020] Starting node 'k3d-kafka-cluster-agent-1'    
INFO[0030] Starting helpers...                          
INFO[0031] Starting node 'k3d-kafka-cluster-serverlb'   
INFO[0038] Injecting records for hostAliases (incl. host.k3d.internal) and for 6 network members into CoreDNS configmap... 
INFO[0041] Cluster 'kafka-cluster' created successfully! 
INFO[0041] You can now use it like this:                
kubectl cluster-info
Waiting for cluster to be ready...
node/k3d-kafka-cluster-agent-0 condition met
node/k3d-kafka-cluster-agent-1 condition met
node/k3d-kafka-cluster-agent-2 condition met
node/k3d-kafka-cluster-server-0 condition met
pod/coredns-576bfc4dc7-mwzr4 condition met
pod/helm-install-traefik-crd-5nmds condition met
pod/helm-install-traefik-mgsq6 condition met
pod/local-path-provisioner-6795b5f9d8-tm57q condition met
pod/metrics-server-557ff575fb-9m7xv condition met
Cluster Installation done...
namespace/database created
created namespace database...
Installing Zookeeper...
service/zookeeper created
statefulset.apps/zookeeper created
pod/zookeeper-0 condition met
```

You can verify that the cluster is ready with:
```shell
(3.12.7) ➜  k3d-kafka kubectl get nodes             
NAME                         STATUS   ROLES                  AGE     VERSION
k3d-kafka-cluster-agent-0    Ready    <none>                 3m57s   v1.30.4+k3s1
k3d-kafka-cluster-agent-1    Ready    <none>                 3m55s   v1.30.4+k3s1
k3d-kafka-cluster-agent-2    Ready    <none>                 3m57s   v1.30.4+k3s1
k3d-kafka-cluster-server-0   Ready    control-plane,master   4m8s    v1.30.4+k3s1
```

Deploy a Kafka cluster as a Kubernetes StatefulSet.

```yaml
# kafka.yaml
# Kafka Service 
apiVersion: v1
kind: Service
metadata:
  name: kafka-svc
  labels:
    app: kafka-app
spec:
  clusterIP: None
  ports:
    - name: '9092'
      port: 9092
      protocol: TCP
      targetPort: 9092
  selector:
    app: kafka-app
---
# Kafka STatefulset
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  labels:
    app: kafka-app
spec:
  serviceName: kafka-svc
  replicas: 3
  selector:
    matchLabels:
      app: kafka-app
  template:
    metadata:
      labels:
        app: kafka-app
    spec:
      containers:
        - name: kafka-container
          image: doughgle/kafka-kraft
          ports:
            - containerPort: 9092
            - containerPort: 9093
          env:
            - name: REPLICAS
              value: '3'
            - name: SERVICE
              value: kafka-svc
            - name: NAMESPACE
              value: default
            - name: SHARE_DIR
              value: /mnt/kafka
            - name: CLUSTER_ID
              value: oh-sxaDRTcyAr6pFRbXyzA
            - name: DEFAULT_REPLICATION_FACTOR
              value: '3'
            - name: DEFAULT_MIN_INSYNC_REPLICAS
              value: '2'
          volumeMounts:
            - name: data
              mountPath: /mnt/kafka
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "1Gi"

```

```shell
(3.12.7) ➜  k3d-kafka kubectl apply -f kafka_cluster/infrastructure/kafka/kafka.yaml 
service/kafka-svc created
statefulset.apps/kafka created
```

Inspect the resources created with:
```shell
(3.12.7) ➜  k3d-kafka kubectl get pods,svc,pvc,pv
NAME          READY   STATUS              RESTARTS   AGE
pod/kafka-0   1/1     Running             0          2m8s
pod/kafka-1   1/1     Running             0          86s
pod/kafka-2   0/1     ContainerCreating   0          79s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/kafka-svc    ClusterIP   None         <none>        9092/TCP   2m8s
service/kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP    12m

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/data-kafka-0   Bound    pvc-b40fc2f5-73db-4f56-a222-763fc7a963ae   1Gi        RWO            local-path     <unset>                 2m8s
persistentvolumeclaim/data-kafka-1   Bound    pvc-e3e58e83-f80a-432f-918a-b2eb3532b5c8   1Gi        RWO            local-path     <unset>                 86s
persistentvolumeclaim/data-kafka-2   Bound    pvc-63c9ecc8-ebb1-4f8a-ba7b-f1a85052b956   1Gi        RWO            local-path     <unset>                 79s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-63c9ecc8-ebb1-4f8a-ba7b-f1a85052b956   1Gi        RWO            Delete           Bound    default/data-kafka-2   local-path     <unset>                          72s
persistentvolume/pvc-b40fc2f5-73db-4f56-a222-763fc7a963ae   1Gi        RWO            Delete           Bound    default/data-kafka-0   local-path     <unset>                          2m2s
persistentvolume/pvc-e3e58e83-f80a-432f-918a-b2eb3532b5c8   1Gi        RWO            Delete           Bound    default/data-kafka-1   local-path     <unset>                          82s
```

```shell
(3.12.7) ➜  k3d-kafka kubectl get pods           
NAME      READY   STATUS    RESTARTS   AGE
kafka-0   1/1     Running   0          3m24s
kafka-1   1/1     Running   0          2m42s
kafka-2   1/1     Running   0          2m35s
```

```shell
(3.12.7) ➜  k3d-kafka kubectl delete pod kafka-0
pod "kafka-0" deleted
```

```shell
(3.12.7) ➜  k3d-kafka kubectl get pods          
NAME      READY   STATUS    RESTARTS   AGE
kafka-0   1/1     Running   0          3s
kafka-1   1/1     Running   0          4m6s
kafka-2   1/1     Running   0          3m59s
```

```shell
(3.12.7) ➜  k3d-kafka kubectl describe service kafka-svc
Name:                     kafka-svc
Namespace:                default
Labels:                   app=kafka-app
Annotations:              <none>
Selector:                 app=kafka-app
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       None
IPs:                      None
Port:                     9092  9092/TCP
TargetPort:               9092/TCP
Endpoints:                10.42.3.10:9092,10.42.2.5:9092,10.42.3.11:9092
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```
Deploy and Run Kafka client:
```shell
kubectl run kafka-client --rm -ti --image bitnami/kafka:3.1.0 -- bash
I have no name!@kafka-producer:/$
```

```shell
I have no name!@kafka-client:/opt/bitnami/kafka/bin$ ls
connect-distributed.sh        kafka-console-consumer.sh    kafka-features.sh            kafka-reassign-partitions.sh        kafka-topics.sh                  zookeeper-server-start.sh
connect-mirror-maker.sh       kafka-console-producer.sh    kafka-get-offsets.sh         kafka-replica-verification.sh       kafka-transactions.sh            zookeeper-server-stop.sh
connect-standalone.sh         kafka-consumer-groups.sh     kafka-leader-election.sh     kafka-run-class.sh                  kafka-verifiable-consumer.sh     zookeeper-shell.sh
kafka-acls.sh                 kafka-consumer-perf-test.sh  kafka-log-dirs.sh            kafka-server-start.sh               kafka-verifiable-producer.sh
kafka-broker-api-versions.sh  kafka-delegation-tokens.sh   kafka-metadata-shell.sh      kafka-server-stop.sh                trogdor.sh
kafka-cluster.sh              kafka-delete-records.sh      kafka-mirror-maker.sh        kafka-storage.sh                    windows
kafka-configs.sh              kafka-dump-log.sh            kafka-producer-perf-test.sh  kafka-streams-application-reset.sh  zookeeper-security-migration.sh
```

bootstrap-server 10.42.3.10:9092,10.42.3.11:9092,10.42.2.5:9092


```shell
(3.12.7) ➜  k3d-kafka kubectl drain k3d-kafka-cluster-agent-0 \
  --delete-emptydir-data \
  --force \
  --ignore-daemonsets
node/k3d-kafka-cluster-agent-0 cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/svclb-traefik-ce5679f6-fgc62
evicting pod kube-system/coredns-576bfc4dc7-mwzr4
pod/coredns-576bfc4dc7-mwzr4 evicted
node/k3d-kafka-cluster-agent-0 drained
```

```shell
(3.12.7) ➜  k3d-kafka kubectl get nodes                                                    
Unable to connect to the server: net/http: TLS handshake timeout
```
The docker has ran out of memory. Increasing the docker ram, cpu and swap has resolved the issue.

helloworld-again