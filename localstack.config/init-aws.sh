#!/bin/bash
awslocal sqs create-queue --queue-name xapi-export
awslocal sqs create-queue --queue-name xapi-ingest

aws --endpoint-url=http://localhost:4566 s3 mb s3://xapi-events
aws --endpoint-url=http://localhost:4566 s3 mb s3://media-library
aws --endpoint-url=http://localhost:4566 s3 mb s3://xapi-inventory
aws --endpoint-url=http://localhost:4566 s3 mb s3://export-downloads

aws --endpoint-url=http://localhost:4576 sqs create-queue --queue-name xapi-export
aws --endpoint-url=http://localhost:4576 sqs create-queue --queue-name xapi-ingest

aws --endpoint-url=http://localhost:4566 s3api put-bucket-notification-configuration --bucket xapi-events --notification-configuration file:///etc/localstack/init/ready.d/config/queue-config.json
