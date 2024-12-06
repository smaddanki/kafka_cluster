import logging

from kafka import KafkaProducer
from kafka.errors import KafkaError

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)

try:
    producer = KafkaProducer(
        bootstrap_servers="localhost:29092",
        security_protocol="PLAINTEXT",
    )

    # Send a test message
    future = producer.send("test-topic", {"test": "message"})
    record_metadata = future.get(timeout=60)
    print(
        f"Message sent to partition {record_metadata.partition} at offset {record_metadata.offset}"
    )

except KafkaError as e:
    print(f"Kafka Error: {str(e)}")
    print(f"Error type: {type(e)}")
except Exception as e:
    print(f"Other Error: {str(e)}")
finally:
    if "producer" in locals():
        producer.close()
