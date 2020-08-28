#!/bin/bash
mkdir -p omb-drivers

NUM_CLUSTERS=1
for i in $(seq 1 ${NUM_CLUSTERS})
do
    cat <<EOF |kubectl apply -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta1
kind: Kafka
metadata:
  name: cluster${i}
spec:
  kafka:
    version: 2.5.0
    replicas: 3
    resources:
      requests:
        cpu: 2
        memory: 3Gi
      limits:
        cpu: 2
        memory: 3Gi
    template:
      pod:
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - topologyKey: "kubernetes.io/hostname"
    listeners:
      plain: {}
#      external:
#        type: route
#        configuration:
#          bootstrap:
#            host: bootstrap.cluster${i}
#          brokers:
#          - broker: 0
#            host: broker-0.cluster${i}
#          - broker: 1
#            host: broker-1.cluster${i}
#          - broker: 2
#            host: broker-2.cluster${i}
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      log.message.format.version: "2.5"
      retention.ms: 300000
      segment.bytes: 1073741824
    storage:
      type: ephemeral
#      type: jbod
#      volumes:
#      - id: 0
#        type: persistent-claim
#        size: 10Gi
#        deleteClaim: false
  zookeeper:
    replicas: 3
    resources:
      requests:
        cpu: 1
        memory: 2Gi
      limits:
        cpu: 1
        memory: 2Gi
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
done

for i in $(seq 1 ${NUM_CLUSTERS})
do
    kubectl wait kafka/cluster${i} --for=condition=Ready --timeout=300s -n kafka
done

for i in $(seq 1 ${NUM_CLUSTERS})
do
    kubectl get secret cluster${i}-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.p12}' | base64 -d > ca-cluster${i}.p12 
    kubectl get secret cluster${i}-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.password}' | base64 -d > ca-password-cluster${i}.txt
cat<<EOF > producer-cluster${i}.properties
bootstrap.servers=bootstrap.cluster${i}:443
security.protocol=SSL
ssl.truststore.location=ca-cluster${i}.p12
ssl.truststore.type=PKCS12
ssl.truststore.password=$(cat ca-password-cluster${i}.txt)
compression.type=none
EOF

cat<<EOF > consumer-cluster${i}.properties
bootstrap.servers=bootstrap.cluster${i}:443
security.protocol=SSL
ssl.truststore.location=ca-cluster${i}.p12
ssl.truststore.type=PKCS12
ssl.truststore.password=$(cat ca-password-cluster${i}.txt)
group.id=perf-consumer-group
EOF

cat<<EOF > omb-drivers/driver-cluster${i}.yaml
name: Kafka
driverClass: io.openmessaging.benchmark.driver.kafka.KafkaBenchmarkDriver

# Kafka client-specific configuration
replicationFactor: 3

topicConfig: |
  min.insync.replicas=2

commonConfig: |
  bootstrap.servers=cluster${i}-kafka-bootstrap.kafka.svc:9092
#  security.protocol=SSL
#  ssl.truststore.location=/certs/ca-cluster${i}.p12
#  ssl.truststore.type=PKCS12
#  ssl.truststore.password=$(cat ca-password-cluster${i}.txt)

producerConfig: |
  acks=all
  linger.ms=1
  batch.size=131072

consumerConfig: |
  auto.offset.reset=earliest
  enable.auto.commit=false
EOF

done
