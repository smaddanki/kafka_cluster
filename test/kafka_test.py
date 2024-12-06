import sys

import six

if sys.version_info >= (3, 12, 0):
    sys.modules["kafka.vendor.six.moves"] = six.moves
import json
from datetime import datetime

from kafka import KafkaConsumer, KafkaProducer

# Producer example
producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    value_serializer=lambda x: json.dumps(x).encode("utf-8"),
    api_version=(0, 10, 1),
    request_timeout_ms=5000,
    security_protocol="PLAINTEXT",
)

# Send a test message
data = {"timestamp": datetime.now().isoformat(), "message": "Test message from Python"}
producer.send("test-topic", value=data)
producer.flush()
print("Message sent!")

# Consumer example
consumer = KafkaConsumer(
    "test-topic",
    bootstrap_servers=["localhost:9092"],
    auto_offset_reset="earliest",
    api_version=(0, 10, 1),
    security_protocol="PLAINTEXT",
    # value_deserializer=lambda x: json.loads(x.decode("utf-8")),
)

print("Waiting for messages...")
for message in consumer:
    print(f"Received: {message.value}")
