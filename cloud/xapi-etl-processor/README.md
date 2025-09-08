# XAPI ETL Processor

An AWS Lambda function for processing XAPI (Experience API) events from S3 into ClickHouse analytics database using ClickHouse's native S3 integration.

## Overview

This Lambda function leverages **ClickHouse S3 integration** for all processing, providing consistent high performance and eliminating Lambda timeout limitations:

- **Event Processing**: Single files triggered by S3 events - processed via ClickHouse S3 integration
- **Bulk Processing**: Multiple files for historical data - processed via ClickHouse S3 integration
- **No Timeout Limits**: All heavy processing is handled by ClickHouse directly from S3
- **Consistent Performance**: Same high-performance approach for all workload sizes

## Architecture

```
S3 Bucket (XAPI Data) → Lambda Function → ClickHouse S3 Integration → ClickHouse Database
                     ↗ (Event Mode)     ↗ (Direct S3 Processing)
Manual Trigger ------→ (Bulk Mode) ----→ (No Lambda Limitations)
```

### Processing Strategy

```
All Files
    │
    ▼
┌─────────────────────┐
│ ClickHouse S3       │
│ Integration         │
│ (High Performance)  │
│ - No timeout limits │
│ - Direct S3 access  │
│ - Parallel processing │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ ClickHouse Database │
│ (All Event Types)   │
└─────────────────────┘
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

## Performance Benefits

### ClickHouse S3 Integration Advantages

All processing now uses ClickHouse's native S3 capabilities for optimal performance:

#### Universal Benefits

- **No Lambda Timeouts**: All processing bypasses the 15-minute Lambda limit
- **High Performance**: ClickHouse processes data directly from S3 using native SQL
- **Cost Effective**: Minimal Lambda execution time for all operations
- **Scalability**: No practical limits on file count or dataset size
- **Consistency**: Same high-performance approach for single files and bulk operations

#### Technical Advantages

- **Parallel Processing**: ClickHouse automatically parallelizes file processing
- **Memory Efficiency**: No data flows through Lambda memory
- **SQL-Based Filtering**: Event type filtering happens at the database level
- **Direct Insertion**: Data goes straight from S3 to final tables

### Configuration Requirements

For S3 integration to work, ensure:

- ClickHouse has network access to S3
- IAM permissions allow ClickHouse to read from your S3 bucket
- ClickHouse S3 table functions are enabled (`s3()` function available)
- Network security groups allow S3 access

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
