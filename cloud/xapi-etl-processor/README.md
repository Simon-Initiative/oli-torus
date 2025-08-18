# XAPI ETL Processor

An AWS Lambda function for processing XAPI (Experience API) events from S3 into ClickHouse analytics database.

## Overview

This Lambda function combines both event processing and bulk processing capabilities in a single deployment:

- **Event Processing Mode**: Processes individual JSONL files triggered by S3 events
- **Bulk Processing Mode**: Handles historical data processing for multiple files

## Architecture

```
S3 Bucket (XAPI Data) → Lambda Function → ClickHouse Database
                     ↗ (Event Mode)
Manual Trigger ------→ (Bulk Mode)
```

## Directory Structure

```
cloud/analytics/
├── xapi-etl-processor/           # Lambda function
│   ├── lambda_function.py        # Main Lambda handler
│   ├── common.py                 # Shared utilities
│   ├── clickhouse_client.py      # ClickHouse database client
│   └── requirements.txt          # Python dependencies
├── deploy.sh           # Deployment script
├── cloudformation.yaml          # AWS infrastructure template
├── test-unified-lambda.py       # Local testing script
└── README.md                    # This file
```

## Function Modes

### Event Processing Mode

Triggered automatically when JSONL files are uploaded to S3:

```json
{
  "bucket": "your-s3-bucket",
  "key": "section/123/video/2024-01-01T12-00-00.000Z_bundle.jsonl"
}
```

Or via S3 event structure:

```json
{
  "Records": [
    {
      "eventSource": "aws:s3",
      "s3": {
        "bucket": { "name": "your-s3-bucket" },
        "object": {
          "key": "section/123/video/2024-01-01T12-00-00.000Z_bundle.jsonl"
        }
      }
    }
  ]
}
```

### Bulk Processing Mode

Triggered manually for historical data processing:

```json
{
  "mode": "bulk",
  "section_id": "123",
  "start_date": "2024-01-01",
  "end_date": "2024-12-31",
  "s3_bucket": "your-s3-bucket",
  "s3_prefix": "section/",
  "dry_run": false,
  "force_reprocess": false
}
```

### Health Check

```json
{
  "health_check": true
}
```

## Mode Detection

The function automatically detects the processing mode based on the event payload:

- **Bulk Mode**: Contains `mode: "bulk"` OR has bulk processing parameters (`section_id`, `start_date`, etc.) without S3 event structure
- **Event Mode**: Contains S3 event structure OR direct `bucket`/`key` parameters
- **Health Check**: Contains `health_check: true`

## Environment Variables

The Lambda function requires these environment variables:

```bash
CLICKHOUSE_HOST=your-clickhouse-host
CLICKHOUSE_PORT=9000
CLICKHOUSE_DATABASE=xapi_analytics
CLICKHOUSE_USERNAME=your-username
CLICKHOUSE_PASSWORD=your-password
S3_XAPI_BUCKET_NAME=your-s3-bucket
ENVIRONMENT=dev|staging|prod
```

## Deployment

### 1. Build and Deploy Package

```bash
# Build deployment package
./deploy.sh

# Build and test locally (requires dependencies)
./deploy.sh --test

# Build and deploy to AWS
./deploy.sh --deploy dev-xapi-etl-processor
```

### 2. Deploy Infrastructure

```bash
# Deploy CloudFormation stack
aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name xapi-etl-dev \
  --parameter-overrides \
    Environment=dev \
    ClickHouseHost=your-host \
    ClickHousePassword=your-password \
  --capabilities CAPABILITY_IAM
```

### 3. Update Function Code

```bash
# Update existing Lambda function
aws lambda update-function-code \
  --function-name dev-xapi-etl-processor \
  --zip-file fileb://xapi-etl-processor.zip
```

## Testing

### Local Development Environment

It is recommended to use a Python virtual environment to isolate dependencies and avoid conflicts with system packages.

#### 1. Create and activate a virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
```

#### 2. Install dependencies

```bash
pip install -r requirements.txt
```

#### 3. Run local tests

```bash
python3 test-unified-lambda.py
```

If you encounter missing package errors, ensure your virtual environment is activated and dependencies are installed.

### Local Testing

```bash
# Test syntax and basic functionality
python3 test-unified-lambda.py
```

## Monitoring

### CloudWatch Logs

- **Log Group**: `/aws/lambda/xapi-etl-processor-{environment}`
- **Retention**: 30 days

### Key Metrics

- `events_processed`: Total XAPI events processed
- `video_events_processed`: Video-specific events inserted into ClickHouse
- `processing_mode`: "event" or "bulk"
- `section_id`: Section being processed
- `success`: Boolean indicating processing success

## Error Handling

### Dead Letter Queue

Failed events are sent to an SQS dead letter queue for retry/investigation.

### Common Errors

1. **ClickHouse Connection**: Check network access and credentials
2. **S3 Access**: Verify IAM permissions for the bucket
3. **JSON Parsing**: Invalid JSONL format in source files
4. **Memory Limits**: Large files may require optimization

## ClickHouse Schema

The clickhouse DB schema is managed by
