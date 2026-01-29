# XAPI ETL Processor (S3 → SQS → Lambda)

This package contains a standalone AWS Lambda implementation that ingests JSONL
objects written to S3, batches them into Parquet format, and streams the Parquet
payload into ClickHouse using the native HTTP `INSERT ... FORMAT Parquet` path.
The design minimises moving pieces: only S3, SQS, Lambda, and ClickHouse are
required.

## Runtime flow

1. **S3 bucket** writes JSON Lines files (one JSON document per line).
2. An **S3 Event Notification** fires on `ObjectCreated` and sends a message to
   an **SQS Standard queue**. The message contains the bucket and key of the
   object.
3. **Lambda** subscribes to the SQS queue. Each invocation receives a batch of
   SQS messages. The handler downloads every referenced object, converts the
   rows into Arrow tables, writes a single Parquet blob in memory, and performs
   an HTTP `INSERT` into ClickHouse.
4. Successful messages are acknowledged via partial batch responses. Failed
   messages remain in the queue and are retried, eventually landing in the DLQ
   if they continue to fail.

## Layout

```
cloud/xapi-etl-processor/
├── lambda_function.py   # Lambda handler & helpers
├── requirements.txt     # Python dependencies
└── README.md            # This guide
```

## Environment variables

| Variable                                  | Description                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `CLICKHOUSE_URL`                          | Full ClickHouse HTTP endpoint (e.g. `https://host:8443`). Overrides host/port/env configuration. |
| `CLICKHOUSE_HOST`                         | ClickHouse host when `CLICKHOUSE_URL` is not provided.                                           |
| `CLICKHOUSE_PORT`                         | Optional port (defaults to 8443 for HTTPS, 8123 otherwise).                                      |
| `CLICKHOUSE_SECURE`                       | `true`/`false` toggle for HTTPS (default `true`).                                                |
| `CLICKHOUSE_PATH`                         | Optional URL suffix (e.g. `/custom/endpoint`).                                                   |
| `CLICKHOUSE_DATABASE`                     | Target database if `CLICKHOUSE_INSERT_SQL` is not set.                                           |
| `CLICKHOUSE_TABLE`                        | Target table if `CLICKHOUSE_INSERT_SQL` is not set.                                              |
| `CLICKHOUSE_INSERT_SQL`                   | Full override for the `INSERT` statement. Use when targeting views or complex inserts.           |
| `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` | Optional Basic Auth credentials.                                                                 |
| `CLICKHOUSE_SETTINGS`                     | Comma-separated ClickHouse settings (e.g. `max_insert_block_size=100000,async_insert=1`).        |
| `CLICKHOUSE_TIMEOUT_SECONDS`              | HTTP timeout in seconds (default `30`).                                                          |
| `PARQUET_COMPRESSION`                     | Parquet compression codec (`snappy` by default).                                                 |
| `MAX_S3_OBJECT_BYTES`                     | Optional soft limit for S3 object size.                                                          |
| `DRY_RUN`                                 | `true` skips the ClickHouse insert but still reads/parses objects (useful for validation).       |
| `LOG_LEVEL`                               | Override logging verbosity (`DEBUG`, `INFO`, `WARN`, etc.).                                      |
| `S3_CONNECT_TIMEOUT_SECONDS`              | S3 client connect timeout (seconds, default `5`).                                                |
| `S3_READ_TIMEOUT_SECONDS`                 | S3 client read timeout (seconds, default `60`).                                                  |
| `S3_MAX_ATTEMPTS`                         | Max retry attempts for S3 operations (default `3`).                                              |
| `ITER_LOG_INTERVAL_SECONDS`               | How often to log progress while streaming JSON lines (seconds, default `5`).                     |
| `DIAG_S3_BUCKET`                          | Optional bucket to probe during diagnostics (list 1 object).                                     |
| `DIAG_S3_PREFIX`                          | Optional prefix used with `DIAG_S3_BUCKET` for diagnostics.                                      |

## Packaging for Lambda

The function now ships with a lightweight handler package and a separate Lambda
Layer that contains the heavy dependencies (`pyarrow`, `numpy`, `requests`).

### 1. Build the Lambda Layer

From `cloud/xapi-etl-processor/` run:

```bash
ARCH_FLAG=linux/amd64   # or linux/arm64 for Graviton Lambdas
docker build --platform "$ARCH_FLAG" \
  --output dist \
  -f layer/Dockerfile .
ls dist/
# xapi-etl-processor-layer.zip
```

Publish the layer and note the returned ARN:

```bash
LAYER_NAME=xapi-etl-processor-deps
aws lambda publish-layer-version \
  --layer-name "$LAYER_NAME" \
  --compatible-runtimes python3.11 \
  --zip-file fileb://dist/xapi-etl-processor-layer.zip

# If the layer archive exceeds the direct upload limit (~70 MB), stage it in S3:
S3_BUCKET=my-layer-artifacts
S3_DEPS_LAYER_KEY=lambda/xapi-etl-processor-layer.zip
aws s3 cp dist/xapi-etl-processor-layer.zip s3://$S3_BUCKET/$S3_DEPS_LAYER_KEY
aws lambda publish-layer-version \
  --layer-name "$LAYER_NAME" \
  --compatible-runtimes python3.11 \
  --content S3Bucket=$S3_BUCKET,S3Key=$S3_DEPS_LAYER_KEY

# Optionally add permissions for other accounts
aws lambda add-layer-version-permission \
  --layer-name "$LAYER_NAME" \
  --version-number <returned-version> \
  --statement-id public-access \
  --principal "*" \
  --action lambda:GetLayerVersion
```

Attach the layer (version ARN) to your Lambda function via the console or:

```bash
aws lambda update-function-configuration \
  --function-name "$LAMBDA_NAME" \
  --layers arn:aws:lambda:REGION:ACCOUNT:layer:$LAYER_NAME:<version>
```

### 2. Package the Handler Code

With dependencies moved into the layer, the handler bundle only contains
`lambda_function.py`:

```bash
cd cloud/xapi-etl-processor
zip -j dist/xapi-etl-processor-handler.zip lambda_function.py
```

Deploy the handler ZIP (small enough for direct upload):

```bash
aws lambda update-function-code \
  --function-name "$LAMBDA_NAME" \
  --zip-file fileb://dist/xapi-etl-processor-handler.zip
```

If you prefer staging in S3, replace the last command with the
`--s3-bucket/--s3-key` variant.

### Diagnostics & observability

- Every cold start logs runtime metadata (Python version, architecture,
  dependency versions). Look for `Lambda cold start runtime metadata` entries in
  CloudWatch.
- Invoke the function manually with `{ "diagnostics": true }` to receive a
  JSON report containing runtime metadata, environment flags, dependency
  versions, and (if configured) an S3 connectivity probe.
- Provide an explicit bucket in the payload to test S3 access:
  `{ "diagnostics": true, "s3_check": { "bucket": "torus-xapi-dev", "prefix": "section/" } }`.
  Alternatively, set `DIAG_S3_BUCKET`/`DIAG_S3_PREFIX` env vars to always run
  this probe during diagnostics calls.
- Set `DRY_RUN=true` to exercise the S3 parsing and Parquet conversion without
  writing to ClickHouse. The summary log records when dry-run mode is active.
- Temporarily raise verbosity with `LOG_LEVEL=DEBUG` to see per-object schema
  details and expanded diagnostics while debugging.

## AWS configuration guide

The following steps assume you have permissions to manage S3, SQS, Lambda, and
IAM within your AWS account. Replace names with values that suit your
environment.

### 1. Create / configure the S3 bucket

- Choose (or create) the source bucket that receives the JSONL objects.
- Ensure the objects are uploaded in JSON Lines format (`.jsonl`) and follow a
  naming convention that is easy to filter with prefix rules.

### 2. Provision the SQS queues

1. Create a **standard** SQS queue, e.g. `xapi-etl-processor-events`.
2. Create a second queue, e.g. `xapi-etl-processor-dlq`, to serve as the DLQ.
3. Configure the main queue with a redrive policy that points to the DLQ (choose
   a `maxReceiveCount` suitable for your retry tolerance, e.g. `5`).
4. Set the main queue visibility timeout to at least **2×** the Lambda timeout.
   Example: Lambda timeout 120s ⇒ Visibility timeout ≥ 240s.
5. Update the main queue **Access policy** to allow the S3 bucket to call
   `sqs:SendMessage`. Example statement:

   ```json
   {
     "Effect": "Allow",
     "Principal": { "Service": "s3.amazonaws.com" },
     "Action": "sqs:SendMessage",
     "Resource": "arn:aws:sqs:REGION:ACCOUNT:QUEUE_NAME",
     "Condition": {
       "ArnEquals": { "aws:SourceArn": "arn:aws:s3:::YOUR_BUCKET" }
     }
   }
   ```

   Replace ARN placeholders with your actual queue and bucket values.

### 3. Configure S3 event notifications

1. In the S3 bucket **Properties > Event notifications** tab, create a notification.
2. Trigger on `All object create events` (or a specific subset if needed).
3. Optionally scope to a prefix (e.g. `etl/`) and/or suffix (`.jsonl`).
4. Choose **Send to SQS queue** and pick the queue from step 2.
5. Save the notification.

### 4. Create the Lambda execution role

1. Create a new IAM role with a **Lambda** service trust policy.
2. Attach the following policies (inline or managed):
   - `AWSLambdaBasicExecutionRole` (logs to CloudWatch).
   - Inline policy allowing `s3:GetObject` on the bucket/prefix you ingest.
   - Inline policy allowing `sqs:ReceiveMessage`, `sqs:DeleteMessage`,
     `sqs:GetQueueAttributes` on the main queue.
   - If using a DLQ with `sqs:SendMessage` from Lambda, add permission for it as
     well.

### 5. Deploy the Lambda function

1. Create a Lambda function (Python 3.11 runtime recommended).
2. Upload the deployment package created above or point to the S3 artifact.
3. Set the handler to `lambda_function.lambda_handler`.
4. Configure memory (e.g. 512–1024 MB) and timeout (e.g. 120s) based on file
   sizes and ClickHouse insert latency.
5. Populate the environment variables listed earlier (database, table, ClickHouse
   endpoint, authentication, etc.).
6. (Optional) Configure a CloudWatch log retention policy.

### 6. Add the SQS trigger

1. In the Lambda console, create an SQS trigger targeting the main queue.
2. Enable **Report batch item failures** (partial batch response).
3. Set the batch size (e.g. `100`) and the maximum batching window (e.g. `60`
   seconds) to allow the queue to accumulate objects before invocation.
4. Ensure the queue's access policy allows the Lambda service principal to poll.

### 7. Test the pipeline

1. Upload a sample JSONL object to the S3 bucket (either manually or via your
   application).
2. Watch the Lambda CloudWatch logs for processing messages.
3. Confirm the data appears in ClickHouse (e.g. `SELECT count(*) FROM table`).
4. If errors occur, inspect the DLQ messages and corresponding logs.

## Operational guidance

- Monitor CloudWatch metrics for Lambda duration, errors, and throttles.
- Use SQS metrics (age of oldest message, DLQ size) to catch backlogs early.
- Enable ClickHouse query logs or use system tables (`system.query_log`) to
  observe inserts.
- Consider enabling VPC integration if ClickHouse is only reachable inside a
  private network (remember to provide VPC subnets and security groups).
- If throughput grows, deploy multiple Lambda functions partitioned by S3 prefix
  or increase memory to gain more CPU for Parquet serialization.

## Local development tips

- Set `AWS_DEFAULT_REGION`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` to
  credentials that can read the S3 test bucket.
- Invoke the handler locally by building a fake event (see
  `tests/` in the previous ETL project for inspiration) and run
  `python lambda_function.py` with a custom runner if needed.
- When testing against a local ClickHouse instance, set `CLICKHOUSE_URL` to the
  local endpoint (e.g. `http://127.0.0.1:8123`).

## Next steps

- Automate deployment with Terraform, CDK, or SAM (not included here).
- Add unit tests that mock S3 and ClickHouse if you plan to iterate locally.
- Extend the lambda to handle additional input formats or enrichments as your
  requirements evolve.

## Local tests

Install dev dependencies and run the unit tests (Python 3.11 recommended so
`pyarrow` wheels are available):

```bash
cd cloud/xapi-etl-processor
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
pytest
```
