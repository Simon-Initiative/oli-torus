# XAPI ETL Processor (S3 → SQS → Lambda)

This package contains a standalone AWS Lambda implementation that ingests JSONL
objects written to S3, batches them into Parquet format, and streams the Parquet
payload into ClickHouse using the native HTTP `INSERT ... FORMAT Parquet` path.
The design minimises moving pieces: only S3, SQS, Lambda, and ClickHouse are
required.

The current implementation uses bounded incremental sub-batching inside each
Lambda invocation. It no longer waits to concatenate every prepared SQS message
into a single invocation-wide insert.

## Runtime flow

1. **S3 bucket** writes JSON Lines files (one JSON document per line).
2. An **S3 Event Notification** fires on `ObjectCreated` and sends a message to
   an **SQS Standard queue**. The message contains the bucket and key of the
   object.
3. **Lambda** subscribes to the SQS queue. Each invocation receives a batch of
   SQS messages. The handler downloads referenced objects, converts them into
   Arrow tables, and accumulates a current in-memory sub-batch.
4. The handler flushes the current sub-batch when one of the configured
   boundaries is reached:
   - preferred row target
   - hard row ceiling
   - payload-size ceiling
   - end of invocation
   - remaining-time safety boundary
5. Each flushed sub-batch is converted into Parquet and inserted into
   ClickHouse over HTTP.
6. Successful messages are acknowledged via partial batch responses. Failed
   or untouched messages remain in the queue and are retried by SQS.
7. Ordinary retryable ClickHouse insert failures are not copied into a custom
   DLQ. Optional DLQ forwarding is reserved for malformed or otherwise
   non-retryable message-preparation failures.

## Layout

```
cloud/xapi-etl-processor/
├── lambda_function.py   # Lambda handler & helpers
├── requirements.txt     # Python dependencies
└── README.md            # This guide
```

## Environment variables

| Variable                                  | Description                                                                                                                                    |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `CLICKHOUSE_URL`                          | Full ClickHouse HTTP endpoint (e.g. `https://host:8443`). Overrides host/port/env configuration.                                               |
| `CLICKHOUSE_HOST`                         | ClickHouse host when `CLICKHOUSE_URL` is not provided.                                                                                         |
| `CLICKHOUSE_PORT`                         | Optional port (defaults to 8443 for HTTPS, 8123 otherwise).                                                                                    |
| `CLICKHOUSE_SECURE`                       | `true`/`false` toggle for HTTPS (default `true`).                                                                                              |
| `CLICKHOUSE_PATH`                         | Optional URL suffix (e.g. `/custom/endpoint`).                                                                                                 |
| `CLICKHOUSE_DATABASE`                     | Target database if `CLICKHOUSE_INSERT_SQL` is not set.                                                                                         |
| `CLICKHOUSE_TABLE`                        | Target table if `CLICKHOUSE_INSERT_SQL` is not set.                                                                                            |
| `CLICKHOUSE_INSERT_SQL`                   | Full override for the `INSERT` statement. Use when targeting views or complex inserts.                                                         |
| `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` | Optional Basic Auth credentials.                                                                                                               |
| `CLICKHOUSE_SETTINGS`                     | Comma-separated ClickHouse settings (e.g. `max_insert_block_size=100000,async_insert=1`).                                                      |
| `CLICKHOUSE_TIMEOUT_SECONDS`              | Maximum HTTP timeout ceiling in seconds. Actual request timeout is derived from remaining Lambda time and capped by this value (default `30`). |
| `PARQUET_COMPRESSION`                     | Parquet compression codec (`snappy` by default).                                                                                               |
| `MAX_S3_OBJECT_BYTES`                     | Optional soft limit for S3 object size.                                                                                                        |
| `TARGET_ROWS_PER_INSERT`                  | Preferred sub-batch row target before flushing (default `10000`).                                                                              |
| `MAX_ROWS_PER_INSERT`                     | Hard sub-batch row ceiling (default `30000`).                                                                                                  |
| `MAX_PARQUET_BYTES_PER_INSERT`            | Soft pre-serialization byte ceiling for a sub-batch (default `16777216`).                                                                      |
| `MIN_REMAINING_TIME_TO_START_INSERT_MS`   | Minimum remaining Lambda time required before concat/serialize/insert work may start (default `15000`).                                        |
| `LAMBDA_TIMEOUT_SAFETY_MARGIN_MS`         | Milliseconds reserved after deriving the request timeout from remaining Lambda budget (default `5000`).                                        |
| `MAX_MESSAGES_PER_INVOCATION_TO_PROCESS`  | Optional code-level cap on how many SQS messages one invocation should prepare before leaving the rest for retry.                              |
| `DRY_RUN`                                 | `true` skips the ClickHouse insert but still reads/parses objects (useful for validation).                                                     |
| `LOG_LEVEL`                               | Override logging verbosity (`DEBUG`, `INFO`, `WARN`, etc.).                                                                                    |
| `S3_CONNECT_TIMEOUT_SECONDS`              | S3 client connect timeout (seconds, default `5`).                                                                                              |
| `S3_READ_TIMEOUT_SECONDS`                 | S3 client read timeout (seconds, default `60`).                                                                                                |
| `S3_MAX_ATTEMPTS`                         | Max retry attempts for S3 operations (default `3`).                                                                                            |
| `ITER_LOG_INTERVAL_SECONDS`               | How often to log progress while streaming JSON lines (seconds, default `5`).                                                                   |
| `DIAG_S3_BUCKET`                          | Optional bucket to probe during diagnostics (list 1 object).                                                                                   |
| `DIAG_S3_PREFIX`                          | Optional prefix used with `DIAG_S3_BUCKET` for diagnostics.                                                                                    |

## Packaging for Lambda

The function ships with a lightweight handler package and a separate Lambda
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
mkdir -p dist
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
- Each non-empty invocation emits structured stage logs for:
  - invocation start and completion
  - per-message preparation
  - sub-batch flush start
  - Arrow concatenation
  - Parquet serialization
  - ClickHouse insert success or failure
  - explicit no-progress outcomes when prepared work cannot safely be committed
- Each flushed sub-batch includes a deterministic `insert_token` in logs and in
  the outbound request headers to help correlate retries and downstream insert
  attempts.
- Invoke the function manually with `{ "diagnostics": true }` to receive a
  JSON report containing runtime metadata, environment flags, dependency
  versions, and (if configured) an S3 connectivity probe.
- Provide an explicit bucket in the payload to test S3 access:
  `{ "diagnostics": true, "s3_check": { "bucket": "torus-xapi-dev", "prefix": "section/" } }`.
  Alternatively, set `DIAG_S3_BUCKET`/`DIAG_S3_PREFIX` env vars to always run
  this probe during diagnostics calls.
- Set `DRY_RUN=true` to exercise the S3 parsing and Parquet conversion without
  writing to ClickHouse. Dry-run sub-batches are still considered committed for
  partial batch response purposes.
- Temporarily raise verbosity with `LOG_LEVEL=DEBUG` to see per-object schema
  details and expanded diagnostics while debugging.

## Recommended initial production posture

These values match the current reliability design and are a better starting
point than the older tiny-Lambda configuration:

- SQS batch size: `50`
- SQS maximum batching window: `60s`
- Lambda memory: `1024 MB`
- Lambda timeout: `60s`
- Event source mapping maximum concurrency: `2`
- SQS visibility timeout: at least `300s`

At low traffic, expect smaller inserts. The implementation flushes smaller
sub-batches when freshness or remaining Lambda budget makes waiting for a
10k-30k row batch unreasonable.

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
4. Set the main queue visibility timeout to at least **5×** the Lambda timeout.
   Example: Lambda timeout 60s ⇒ Visibility timeout ≥ 300s.
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
4. Start with memory `1024 MB` and timeout `60s`, then tune after observing
   actual sub-batch size, insert latency, and backlog behavior.
5. Populate the environment variables listed earlier (database, table, ClickHouse
   endpoint, authentication, etc.).
6. (Optional) Configure a CloudWatch log retention policy.

### 6. Add the SQS trigger

1. In the Lambda console, create an SQS trigger targeting the main queue.
2. Enable **Report batch item failures** (partial batch response).
3. Start with batch size `50` and maximum batching window `60s`.
4. Set event source mapping maximum concurrency to `2` initially.
5. Ensure the queue's access policy allows the Lambda service principal to poll.

## Maintenance posture

Planned ClickHouse downtime is handled operationally through SQS buffering:

1. Disable the Lambda SQS event source mapping before maintenance.
2. Let SQS backlog accumulate while ClickHouse is unavailable.
3. Re-enable the mapping once ClickHouse is healthy again.
4. Watch queue depth, oldest message age, and drain rate alarms while the
   backlog clears.

This is an alarm-driven manual model. The Lambda itself does not auto-pause or
auto-resume consumption.

### 7. Test the pipeline

1. Upload a sample JSONL object to the S3 bucket (either manually or via your
   application).
2. Watch the Lambda CloudWatch logs for processing messages.
3. Confirm the data appears in ClickHouse (e.g. `SELECT count(*) FROM table`).
4. If preparation fails, inspect the DLQ messages and corresponding logs.
5. If ClickHouse insert failures occur, expect the source SQS messages to be
   retried in place rather than mirrored into the custom DLQ.

## ClickHouse credential management

Use a dedicated ClickHouse service user for this Lambda. Do not use a shared
admin/default account.

### Provision a least-privilege user

Run as a ClickHouse admin user:

```sql
CREATE USER IF NOT EXISTS xapi_etl_processor
  IDENTIFIED WITH sha256_password BY '<strong-random-password>';

GRANT INSERT ON oli_analytics.raw_events TO xapi_etl_processor;
```

Optional hardening (adjust to your cluster baseline):

```sql
ALTER USER xapi_etl_processor SETTINGS
  max_execution_time = 60,
  max_memory_usage = 2000000000,
  max_threads = 4;
```

Verify effective grants:

```sql
SHOW GRANTS FOR xapi_etl_processor;
```

### Configure Lambda credentials

Set these Lambda environment variables:

- `CLICKHOUSE_USER=xapi_etl_processor`
- `CLICKHOUSE_PASSWORD=<strong-random-password>`
- `CLICKHOUSE_DATABASE=oli_analytics`
- `CLICKHOUSE_TABLE=raw_events`

If you manage env vars via CLI, note that `update-function-configuration`
replaces the entire `Variables` object. Merge with existing values before
updating.

### Rotation playbook

1. Create a new password for `xapi_etl_processor`:

   ```sql
   ALTER USER xapi_etl_processor IDENTIFIED WITH sha256_password BY '<new-strong-password>';
   ```

2. Update Lambda env vars to the new secret.
3. Validate ingestion with a test JSONL upload and confirm inserts in
   `raw_events`.
4. If rotation used a temporary user, remove the old user after validation:

   ```sql
   DROP USER IF EXISTS xapi_etl_processor_old;
   ```

For zero-downtime rotations on strict environments, use a dual-user approach:
create `xapi_etl_processor_v2`, grant `INSERT`, switch Lambda credentials, then
drop or disable the old user after validation.

## Operational guidance

- Monitor CloudWatch metrics for Lambda duration, errors, and throttles.
- Use SQS metrics (age of oldest message, DLQ size) to catch backlogs early.
- Enable ClickHouse query logs or use system tables (`system.query_log`) to
  observe inserts.
- Consider enabling VPC integration if ClickHouse is only reachable inside a
  private network (remember to provide VPC subnets and security groups).
- If throughput grows, deploy multiple Lambda functions partitioned by S3 prefix
  or increase memory to gain more CPU for Parquet serialization.
- Use `docs/runbooks/clickhouse/operations.md` for reset, backfill, restart, and maintenance flow.
- Use `docs/runbooks/clickhouse/backup-restore.md` for backup and restore validation procedures.

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
