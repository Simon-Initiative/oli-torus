# XAPI Analytics ETL Pipeline - Developer Guide

This guide provides comprehensive instructions for setting up, configuring, and using the XAPI Analytics ETL pipeline.

## Overview

The XAPI Analytics ETL pipeline processes learning analytics events (xAPI statements) from S3 storage into ClickHouse for analysis. The system supports multiple deployment modes:

1. **Development Mode (Direct)**: Events are uploaded directly to local ClickHouse
2. **Development Mode (Lambda)**: Events are processed through AWS Lambda (for testing production pipeline)
3. **Production Mode**: Events are uploaded to S3, then processed by AWS Lambda into ClickHouse

## Architecture

```
Oli Torus App → S3 JSONL Files → AWS Lambda ETL → ClickHouse
                      ↓
              (Development modes bypass S3)
```

### Components

- **Oli Torus Application**: Generates XAPI events from user interactions
- **Upload Pipeline**: Batches and uploads events (configurable destination)
- **S3 Storage**: Stores JSONL files in production
- **Lambda Functions**: Process JSONL files and load into ClickHouse
- **ClickHouse**: OLAP database for analytics queries

## Configuration

### Environment Variables

Add these variables to your `oli.env` file:

```bash
# XAPI ETL Pipeline Mode
# Options: direct, lambda, s3
XAPI_ETL_MODE=direct

# Lambda function names (when using lambda mode)
XAPI_LAMBDA_FUNCTION_NAME=xapi-etl-processor-dev

# ClickHouse configuration
CLICKHOUSE_HOST=localhost
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=clickhouse
CLICKHOUSE_DATABASE=default

# AWS configuration (for lambda mode)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# S3 bucket for XAPI data
S3_XAPI_BUCKET_NAME=your-xapi-bucket
```

### Development Modes

#### 1. Direct Mode (Default)

```bash
XAPI_ETL_MODE=direct
```

Events are uploaded directly to local ClickHouse. Best for local development.

#### 2. Lambda Mode (Testing)

```bash
XAPI_ETL_MODE=lambda
XAPI_LAMBDA_FUNCTION_NAME=xapi-etl-processor-dev
```

Events are sent to AWS Lambda for processing. Useful for testing the production ETL pipeline.

#### 3. Production Mode

```bash
XAPI_ETL_MODE=s3
```

Events are uploaded to S3, then processed by Lambda. Used in production.

## Setup Instructions

### 1. Local Development Setup

1. **Start ClickHouse**:

   ```bash
   docker-compose up clickhouse
   ```

2. **Initialize ClickHouse tables**:

   ```bash
   mix oli.clickhouse.setup
   ```

3. **Configure environment**:

   ```bash
   cp oli.example.env oli.env
   # Edit oli.env with your configuration
   ```

4. **Start the application**:
   ```bash
   mix phx.server
   ```

### 2. Lambda Development Setup

1. **Deploy Lambda functions**:

   ```bash
   cd cloud/analytics
   ./deploy.sh dev us-east-1
   ```

   **Note**: The deployment script automatically copies shared Python modules (`common.py`, `clickhouse_client.py`) into each Lambda package. This ensures compatibility across platforms and deployment environments without relying on symlinks.

2. **Configure Lambda environment variables** in AWS Console:

   - `CLICKHOUSE_HOST` - Your ClickHouse hostname (use ngrok for local testing)
   - `CLICKHOUSE_PORT` - ClickHouse HTTP port (8123)
   - `CLICKHOUSE_USER` - ClickHouse username
   - `CLICKHOUSE_PASSWORD` - ClickHouse password
   - `CLICKHOUSE_DATABASE` - ClickHouse database name
   - `S3_XAPI_BUCKET_NAME` - S3 bucket for XAPI data

3. **Set up ngrok for local ClickHouse access** (optional):

   ```bash
   ngrok http 8123
   # Use the ngrok URL as CLICKHOUSE_HOST in Lambda
   ```

4. **Test Lambda mode**:
   ```bash
   # In oli.env
   XAPI_ETL_MODE=lambda
   ```

### 3. Production Setup

1. **Deploy infrastructure**:

   ```bash
   aws cloudformation create-stack \
     --stack-name xapi-etl-prod \
     --template-body file://cloudformation.yaml \
     --parameters ParameterKey=Environment,ParameterValue=prod \
                  ParameterKey=S3XAPIBucketName,ParameterValue=your-xapi-bucket \
     --capabilities CAPABILITY_NAMED_IAM
   ```

2. **Deploy Lambda code**:

   ```bash
   ./deploy.sh prod us-east-1
   ```

3. **Configure S3 event triggers** (if not using CloudFormation EventBridge rule):
   ```bash
   aws s3api put-bucket-notification-configuration \
     --bucket your-xapi-bucket \
     --notification-configuration file://s3-notification.json
   ```

## Usage

### Automatic Processing

In production, XAPI events are automatically processed when uploaded to S3.

### Manual Bulk Processing

Use the Jupyter notebook to process historical data:

1. **Open the notebook**:

   ```bash
   jupyter notebook cloud/analytics/bulk_etl_notebook.ipynb
   ```

2. **Configure AWS credentials and environment**

3. **Run bulk processing for specific sections**:

   ```python
   # Process section 123 data
   payload = {
       'section_id': '123',
       'start_date': '2024-01-01',
       'end_date': '2024-12-31'
   }

   result = invoke_lambda_async('bulk_etl_processor-dev', payload)
   ```

### Python API for Bulk Processing

```python
import boto3
import json

lambda_client = boto3.client('lambda')

# Process specific section
payload = {
    'section_id': '123',
    'start_date': '2024-01-01',
    'end_date': '2024-12-31',
    'force_reprocess': False
}

response = lambda_client.invoke(
    FunctionName='bulk_etl_processor-dev',
    InvocationType='Event',  # Async
    Payload=json.dumps(payload)
)
```

## Monitoring

### CloudWatch Logs

Monitor Lambda execution:

- `/aws/lambda/process_xapi_events-{env}`
- `/aws/lambda/bulk_etl_processor-{env}`

### ClickHouse Queries

Check data ingestion:

```sql
-- Total events
SELECT COUNT(*) FROM default.video_events;

-- Events by section
SELECT section_id, COUNT(*) as event_count
FROM default.video_events
GROUP BY section_id
ORDER BY event_count DESC;

-- Recent events
SELECT *
FROM default.video_events
ORDER BY timestamp DESC
LIMIT 10;
```

### Application Monitoring

Check the upload pipeline status in the admin interface:

- `/admin/xapi_upload_pipeline` - Pipeline statistics
- `/admin/clickhouse` - ClickHouse analytics dashboard

## Testing

Run the comprehensive test suite:

```bash
cd /Users/eliknebel/Developer/oli-torus
./cloud/analytics/test.sh
```

### Manual Testing

1. **Test Lambda function**:

   ```bash
   aws lambda invoke \
     --function-name xapi-etl-processor-dev \
     --payload '{"health_check": true}' \
     response.json
   ```

2. **Test ClickHouse connection**:

   ```bash
   curl -X POST 'http://localhost:8123' \
     -H 'X-ClickHouse-User: default' \
     -H 'X-ClickHouse-Key: clickhouse' \
     -d 'SELECT 1'
   ```

3. **Generate test data**:
   - Watch videos in the delivery interface
   - Events will be automatically processed based on your XAPI_ETL_MODE

## Troubleshooting

### Common Issues

1. **ClickHouse connection failed**:

   - Check if ClickHouse is running: `docker-compose ps clickhouse`
   - Verify credentials in environment variables
   - For Lambda testing, ensure ngrok tunnel is active

2. **Lambda invocation failed**:

   - Check AWS credentials and permissions
   - Verify Lambda function exists and is deployed
   - Check CloudWatch logs for error details

3. **Events not appearing in ClickHouse**:

   - Check that video_events table exists
   - Verify event format matches expected schema
   - Check Lambda logs for processing errors

4. **S3 events not triggering Lambda**:
   - Verify S3 event configuration
   - Check Lambda permissions for S3 invocation
   - Ensure file extensions match (.jsonl)

### Debug Mode

Enable debug logging:

```bash
# In oli.env
LOG_LEVEL=debug

# For Lambda functions, set environment variable:
# LOG_LEVEL=DEBUG
```

### Data Validation

Verify data integrity:

```sql
-- Check for duplicate events
SELECT event_id, COUNT(*)
FROM default.video_events
GROUP BY event_id
HAVING COUNT(*) > 1;

-- Check timestamp ranges
SELECT
    MIN(timestamp) as earliest,
    MAX(timestamp) as latest,
    COUNT(*) as total_events
FROM default.video_events;
```

## Performance Tuning

### Lambda Configuration

- **Memory**: 512MB for process_xapi_events, 1024MB for bulk_etl_processor
- **Timeout**: 300s for process_xapi_events, 900s for bulk_etl_processor
- **Concurrency**: Set reserved concurrency based on ClickHouse capacity

### ClickHouse Optimization

- **Partitioning**: Events are partitioned by month (`toYYYYMM(timestamp)`)
- **Ordering**: Optimized for section-based queries (`section_id, timestamp, user_id`)
- **Batch Size**: Configure based on memory and network capacity

### Pipeline Tuning

Configure in `oli.env`:

```bash
# Batch processing settings
XAPI_BATCH_SIZE=50
XAPI_BATCHER_CONCURRENCY=20
XAPI_PROCESSOR_CONCURRENCY=2
XAPI_BATCH_TIMEOUT=5000
```

## Security Considerations

1. **ClickHouse Access**: Use strong passwords and restrict network access
2. **AWS Credentials**: Use IAM roles instead of access keys when possible
3. **S3 Permissions**: Limit bucket access to necessary resources only
4. **Lambda Permissions**: Follow principle of least privilege

## Maintenance

### Regular Tasks

1. **Monitor CloudWatch logs** for errors
2. **Check ClickHouse disk usage** and optimize partitions
3. **Review Lambda costs** and optimize memory/timeout settings
4. **Update Lambda code** when dependencies change

### Backup and Recovery

1. **ClickHouse backups**: Use ClickHouse backup tools
2. **S3 data retention**: Configure lifecycle policies
3. **Lambda code**: Version control and automated deployment

## Support

For issues and questions:

1. Check CloudWatch logs for error details
2. Review this documentation
3. Run the test suite to identify configuration issues
4. Check the oli-torus repository issues for known problems
