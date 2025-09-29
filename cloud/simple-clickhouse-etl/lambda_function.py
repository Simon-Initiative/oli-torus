"""AWS Lambda entrypoint for an S3 → SQS → Lambda → ClickHouse ETL pipeline.

The handler expects to be invoked by an SQS event where each message body is an
S3 ObjectCreated notification in JSON format. For every SQS message the Lambda
reads the referenced JSON Lines object from S3, converts the payload into an
Arrow table, batches the successful records into a single Parquet payload, and
streams that payload into ClickHouse using the HTTP interface.

Environment variables
---------------------
CLICKHOUSE_URL             Optional full base URL (e.g. https://host:8443)
CLICKHOUSE_HOST            Hostname when CLICKHOUSE_URL is not provided
CLICKHOUSE_PORT            Port number (defaults to 8443 if secure else 8123)
CLICKHOUSE_SECURE          "true" | "false" (defaults to true)
CLICKHOUSE_PATH            Optional URL path suffix (e.g. /custom/endpoint)
CLICKHOUSE_DATABASE        Target database (required when using host/port form)
CLICKHOUSE_TABLE           Target table (required when using host/port form)
CLICKHOUSE_INSERT_SQL      Full INSERT statement override (optional)
CLICKHOUSE_USER            Basic auth user (optional)
CLICKHOUSE_PASSWORD        Basic auth password (optional)
CLICKHOUSE_SETTINGS        Comma separated ClickHouse setting overrides
PARQUET_COMPRESSION        Compression codec (defaults to snappy)
CLICKHOUSE_TIMEOUT_SECONDS Request timeout for HTTP insert (default 30)
MAX_S3_OBJECT_BYTES        Soft cap per S3 object (bytes); raises if exceeded

The handler returns the partial batch response structure required for SQS event
source mappings with the "ReportBatchItemFailures" feature.
"""
from __future__ import annotations

import importlib
import io
import json
import logging
import os
import platform
import time
import sys
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import unquote_plus

import boto3
from botocore.config import Config
import requests
from requests.auth import HTTPBasicAuth

try:  # Preload PyArrow but keep diagnostics if it fails
    import pyarrow as pa
    import pyarrow.parquet as pq
    PYARROW_IMPORT_ERROR: Optional[Exception] = None
except Exception as exc:  # pylint: disable=broad-except
    pa = None  # type: ignore[assignment]
    pq = None  # type: ignore[assignment]
    PYARROW_IMPORT_ERROR = exc

try:
    import numpy  # pylint: disable=import-outside-toplevel
    NUMPY_IMPORT_ERROR: Optional[Exception] = None
except Exception as exc:  # pylint: disable=broad-except
    numpy = None  # type: ignore[assignment]
    NUMPY_IMPORT_ERROR = exc

logger = logging.getLogger(__name__)

_LOG_LEVEL_NAME = os.getenv("LOG_LEVEL", "INFO").upper()
logger.setLevel(getattr(logging, _LOG_LEVEL_NAME, logging.INFO))


def _build_runtime_metadata() -> Dict[str, Any]:
    metadata: Dict[str, Any] = {
        "python_version": sys.version.split()[0],
        "python_compiler": platform.python_compiler(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "log_level": _LOG_LEVEL_NAME,
    }
    if PYARROW_IMPORT_ERROR is None:
        metadata["pyarrow_version"] = getattr(pa, "__version__", "unknown")
    else:
        metadata["pyarrow_error"] = str(PYARROW_IMPORT_ERROR)
    try:
        import numpy  # pylint: disable=import-outside-toplevel

        metadata["numpy_version"] = getattr(numpy, "__version__", "unknown")
    except Exception as exc:  # pylint: disable=broad-except
        metadata["numpy_version_error"] = str(exc)
    return metadata


RUNTIME_METADATA = _build_runtime_metadata()
logger.info("Lambda cold start runtime metadata: %s", json.dumps(RUNTIME_METADATA))

_S3_CONNECT_TIMEOUT = float(os.getenv("S3_CONNECT_TIMEOUT_SECONDS", "5"))
_S3_READ_TIMEOUT = float(os.getenv("S3_READ_TIMEOUT_SECONDS", "60"))
_S3_MAX_ATTEMPTS = int(os.getenv("S3_MAX_ATTEMPTS", "3"))

s3_client = boto3.client(
    "s3",
    config=Config(
        connect_timeout=_S3_CONNECT_TIMEOUT,
        read_timeout=_S3_READ_TIMEOUT,
        retries={"max_attempts": _S3_MAX_ATTEMPTS},
    ),
)


@dataclass(frozen=True)
class S3ObjectRef:
    bucket: str
    key: str


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Entry point for Lambda."""
    if is_diagnostics_request(event):
        diagnostics = collect_runtime_diagnostics(event)
        logger.info("Diagnostics request served")
        return {"statusCode": 200, "body": json.dumps(diagnostics)}

    ensure_pyarrow_available()

    records = event.get("Records", [])
    logger.info("Received %d SQS messages", len(records))

    tables_to_insert: List[pa.Table] = []
    message_ids_for_insert: List[str] = []
    empty_message_ids: List[str] = []
    failures: List[str] = []
    total_rows = 0
    total_objects = 0
    dry_run_enabled = env_flag("DRY_RUN", default=False)

    for record in records:
        message_id = record.get("messageId", "<unknown>")
        try:
            s3_refs = list(extract_s3_references(record))
            if not s3_refs:
                raise ValueError("SQS record did not contain any S3 references")

            logger.debug(
                "Message %s references %d S3 objects", message_id, len(s3_refs)
            )

            fetch_started = time.perf_counter()
            table = build_arrow_table_from_s3_objects(s3_refs)
            fetch_elapsed = time.perf_counter() - fetch_started
            logger.info(
                "Completed fetch for message %s in %.2fs",
                message_id,
                fetch_elapsed,
            )
            if table is None or table.num_rows == 0:
                logger.info("Message %s produced no rows; acknowledging without insert", message_id)
                empty_message_ids.append(message_id)
                continue

            tables_to_insert.append(table)
            message_ids_for_insert.append(message_id)
            total_rows += table.num_rows
            total_objects += len(s3_refs)
            logger.info(
                "Prepared %d rows from %d S3 objects for message %s",
                table.num_rows,
                len(s3_refs),
                message_id,
            )
        except Exception as exc:  # pylint: disable=broad-except
            logger.exception("Failed to prepare SQS message %s: %s", message_id, exc)
            failures.append(message_id)

    if tables_to_insert:
        logger.info("Attempting ClickHouse insert for %d prepared messages", len(message_ids_for_insert))
        try:
            combined_table = concatenate_tables(tables_to_insert)
            parquet_payload = table_to_parquet(combined_table)
            if dry_run_enabled:
                logger.info(
                    "DRY_RUN enabled; skipping ClickHouse insert for %d rows from %d messages",
                    combined_table.num_rows,
                    len(message_ids_for_insert),
                )
            else:
                insert_started = time.perf_counter()
                insert_into_clickhouse(parquet_payload, combined_table.num_rows)
                logger.info(
                    "Inserted %d total rows into ClickHouse from %d messages",
                    combined_table.num_rows,
                    len(message_ids_for_insert),
                )
                logger.debug(
                    "ClickHouse insert completed in %.2fs",
                    time.perf_counter() - insert_started,
                )
        except Exception as exc:  # pylint: disable=broad-except
            logger.exception("ClickHouse insert failed: %s", exc)
            failures.extend(message_ids_for_insert)

    unique_failures = sorted(set(failures))
    summary = {
        "processed_messages": len(message_ids_for_insert),
        "empty_messages": len(empty_message_ids),
        "failed_messages": len(unique_failures),
        "total_rows": total_rows,
        "total_s3_objects": total_objects,
        "dry_run": dry_run_enabled,
    }
    if unique_failures:
        logger.warning("Batch completed with failures: %s", json.dumps(summary))
    else:
        logger.info("Batch completed successfully: %s", json.dumps(summary))

    return {"batchItemFailures": [{"itemIdentifier": item_id} for item_id in unique_failures]}


def extract_s3_references(record: Dict[str, Any]) -> Iterable[S3ObjectRef]:
    """Parse S3 bucket/key pairs from an SQS record."""
    body = record.get("body")
    if body is None:
        return []

    payload = json.loads(body)

    # S3 notifications delivered via SNS embed the payload inside Message
    if isinstance(payload, dict) and "Message" in payload and not payload.get("Records"):
        try:
            payload = json.loads(payload["Message"])
        except json.JSONDecodeError:
            logger.debug("Message field of SQS record %s is not JSON", record.get("messageId"))

    if isinstance(payload, dict) and "Records" in payload:
        for s3_record in payload["Records"]:
            yield from _extract_from_s3_event_record(s3_record)
        return

    # Fallback for custom minimal payloads {"bucket": "...", "key": "..."}
    if isinstance(payload, dict) and {"bucket", "key"}.issubset(payload):
        yield S3ObjectRef(bucket=payload["bucket"], key=payload["key"])
        return

    raise ValueError("Unsupported SQS message body; expected S3 event structure")


def _extract_from_s3_event_record(s3_record: Dict[str, Any]) -> Iterable[S3ObjectRef]:
    if not isinstance(s3_record, dict):
        return []
    s3_body = s3_record.get("s3")
    if not isinstance(s3_body, dict):
        return []
    bucket_info = s3_body.get("bucket") or {}
    object_info = s3_body.get("object") or {}
    bucket = bucket_info.get("name")
    key = object_info.get("key")
    if not bucket or not key:
        return []
    yield S3ObjectRef(bucket=bucket, key=unquote_plus(key))


def build_arrow_table_from_s3_objects(objects: Iterable[S3ObjectRef]) -> Optional[pa.Table]:
    """Load JSONL objects from S3 and convert to a single Arrow table."""
    tables: List[pa.Table] = []
    for ref in objects:
        table = load_json_lines_as_table(ref)
        if table is not None:
            tables.append(table)
    if not tables:
        return None
    return concatenate_tables(tables)


def load_json_lines_as_table(ref: S3ObjectRef) -> Optional[pa.Table]:
    """Read a JSON Lines object from S3 into an Arrow table."""
    ensure_pyarrow_available()
    max_bytes_env = os.getenv("MAX_S3_OBJECT_BYTES")
    max_bytes = int(max_bytes_env) if max_bytes_env else None
    logger.info("Fetching s3://%s/%s", ref.bucket, ref.key)

    fetch_started = time.perf_counter()

    response = s3_client.get_object(Bucket=ref.bucket, Key=ref.key)
    body = response["Body"]
    content_length = response.get("ContentLength")
    if content_length is not None:
        logger.info(
            "Object size for s3://%s/%s is %.2f MB",
            ref.bucket,
            ref.key,
            content_length / (1024 * 1024),
        )

    if max_bytes is not None:
        # peek at the content length provided by S3 to fail early
        object_size = response.get("ContentLength")
        if object_size and object_size > max_bytes:
            raise ValueError(
                f"S3 object s3://{ref.bucket}/{ref.key} is {object_size} bytes which exceeds MAX_S3_OBJECT_BYTES"
            )

    rows: List[Dict[str, Any]] = []
    log_interval_seconds = float(os.getenv("ITER_LOG_INTERVAL_SECONDS", "5"))
    next_log_deadline = fetch_started + log_interval_seconds

    for index, raw_line in enumerate(body.iter_lines(chunk_size=1024 * 64), start=1):
        if not raw_line:
            continue
        try:
            rows.append(json.loads(raw_line))
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Invalid JSON in s3://{ref.bucket}/{ref.key}: {raw_line[:200]!r}"
            ) from exc

        now = time.perf_counter()
        if now >= next_log_deadline:
            logger.debug(
                "Read %d lines from s3://%s/%s (%.2fs elapsed)",
                index,
                ref.bucket,
                ref.key,
                now - fetch_started,
            )
            next_log_deadline = now + log_interval_seconds

    if not rows:
        logger.info("S3 object s3://%s/%s contained no JSON rows", ref.bucket, ref.key)
        return None

    try:
        table = pa.Table.from_pylist(rows)
        logger.debug(
            "Constructed Arrow table with %d rows and schema %s from s3://%s/%s",
            table.num_rows,
            table.schema,
            ref.bucket,
            ref.key,
        )
        logger.info(
            "Parsed %d rows from s3://%s/%s in %.2fs",
            table.num_rows,
            ref.bucket,
            ref.key,
            time.perf_counter() - fetch_started,
        )
        return table
    except Exception as exc:  # pylint: disable=broad-except
        raise ValueError(f"Unable to convert rows from s3://{ref.bucket}/{ref.key} into Arrow table") from exc


def concatenate_tables(tables: List[pa.Table]) -> pa.Table:
    ensure_pyarrow_available()
    if not tables:
        raise ValueError("concatenate_tables received no tables")
    if len(tables) == 1:
        return tables[0]
    return pa.concat_tables(tables, promote=True)


def table_to_parquet(table: pa.Table) -> bytes:
    ensure_pyarrow_available()
    compression = os.getenv("PARQUET_COMPRESSION", "snappy")
    buffer = io.BytesIO()
    pq.write_table(table, buffer, compression=compression)
    return buffer.getvalue()


def insert_into_clickhouse(parquet_payload: bytes, row_count: int) -> None:
    url = resolve_clickhouse_url()
    query = build_insert_query()
    params = {"query": query}
    params.update(parse_clickhouse_settings())

    timeout = float(os.getenv("CLICKHOUSE_TIMEOUT_SECONDS", "30"))
    headers = {"Content-Type": "application/octet-stream"}

    logger.debug("Sending %d rows to ClickHouse via %s", row_count, url)

    auth = None
    user = os.getenv("CLICKHOUSE_USER")
    password = os.getenv("CLICKHOUSE_PASSWORD")
    if user and password is not None:
        auth = HTTPBasicAuth(user, password)

    response = requests.post(  # noqa: S113 -- AWS Lambda sandbox restricts sockets but requests is acceptable here
        url,
        params=params,
        data=parquet_payload,
        headers=headers,
        timeout=timeout,
        auth=auth,
    )
    if response.status_code >= 400:
        raise RuntimeError(
            f"ClickHouse insert failed with status {response.status_code}: {response.text}"
        )

    logger.debug("ClickHouse response: %s", response.text.strip())


def resolve_clickhouse_url() -> str:
    explicit = os.getenv("CLICKHOUSE_URL")
    if explicit:
        return explicit.rstrip("/")

    host = os.getenv("CLICKHOUSE_HOST")
    if not host:
        raise ValueError("CLICKHOUSE_HOST (or CLICKHOUSE_URL) must be set")

    secure = os.getenv("CLICKHOUSE_SECURE", "true").lower() == "true"
    protocol = "https" if secure else "http"
    default_port = "8443" if secure else "8123"
    port = os.getenv("CLICKHOUSE_PORT", default_port)
    path = os.getenv("CLICKHOUSE_PATH", "")
    if path and not path.startswith("/"):
        path = f"/{path}"

    return f"{protocol}://{host}:{port}{path}".rstrip("/")


def build_insert_query() -> str:
    override = os.getenv("CLICKHOUSE_INSERT_SQL")
    if override:
        return override

    database = os.getenv("CLICKHOUSE_DATABASE")
    table = os.getenv("CLICKHOUSE_TABLE")
    if not database or not table:
        raise ValueError(
            "CLICKHOUSE_DATABASE and CLICKHOUSE_TABLE must be set when CLICKHOUSE_INSERT_SQL is not provided"
        )

    return f"INSERT INTO {quote_identifier(database)}.{quote_identifier(table)} FORMAT Parquet"


def quote_identifier(identifier: str) -> str:
    return f"`{identifier.replace('`', '``')}`"


def parse_clickhouse_settings() -> Dict[str, str]:
    settings_env = os.getenv("CLICKHOUSE_SETTINGS")
    if not settings_env:
        return {}
    settings: Dict[str, str] = {}
    for item in settings_env.split(","):
        if not item.strip():
            continue
        if "=" not in item:
            logger.warning("Ignoring invalid CLICKHOUSE_SETTINGS entry: %s", item)
            continue
        key, value = item.split("=", 1)
        settings[key.strip()] = value.strip()
    return settings


def env_flag(name: str, default: bool = False) -> bool:
    value = os.getenv(name, None)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "t", "yes", "on"}


def is_diagnostics_request(event: Any) -> bool:
    return isinstance(event, dict) and bool(event.get("diagnostics"))


def collect_runtime_diagnostics(event: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    diagnostics: Dict[str, Any] = {
        "runtime": RUNTIME_METADATA,
        "environment": {
            "dry_run": env_flag("DRY_RUN", default=False),
            "log_level": _LOG_LEVEL_NAME,
            "has_clickhouse_url": bool(os.getenv("CLICKHOUSE_URL")),
            "has_clickhouse_host": bool(os.getenv("CLICKHOUSE_HOST")),
        },
        "dependencies": {},
    }
    if PYARROW_IMPORT_ERROR is None:
        diagnostics["dependencies"]["pyarrow"] = getattr(pa, "__version__", "unknown")
    else:
        diagnostics["dependencies"]["pyarrow_error"] = str(PYARROW_IMPORT_ERROR)
    try:
        numpy_module = importlib.import_module("numpy")
        diagnostics["dependencies"]["numpy"] = getattr(numpy_module, "__version__", "unknown")
    except Exception as exc:  # pylint: disable=broad-except
        diagnostics["dependencies"]["numpy_error"] = str(exc)
    maybe_add_s3_check(diagnostics, event)
    return diagnostics


def maybe_add_s3_check(diagnostics: Dict[str, Any], event: Optional[Dict[str, Any]]) -> None:
    request_payload = event or {}
    s3_check_request = None
    if isinstance(request_payload, dict):
        s3_check_request = request_payload.get("s3_check")

    if s3_check_request is None:
        env_bucket = os.getenv("DIAG_S3_BUCKET")
        env_prefix = os.getenv("DIAG_S3_PREFIX")
        if env_bucket:
            s3_check_request = {"bucket": env_bucket, "prefix": env_prefix}

    if not isinstance(s3_check_request, dict):
        return

    bucket = s3_check_request.get("bucket")
    if not bucket:
        diagnostics.setdefault("s3_check", {})["error"] = "bucket not provided"
        return

    prefix = s3_check_request.get("prefix")
    try:
        debug_payload = {
            "bucket": bucket,
            "prefix": prefix,
            "max_keys": 1,
        }
        response = s3_client.list_objects_v2(
            Bucket=bucket,
            Prefix=prefix or "",
            MaxKeys=1,
        )
        diagnostics["s3_check"] = {
            "request": debug_payload,
            "status": "ok",
            "key_found": bool(response.get("KeyCount")),
        }
        first_obj = None
        contents = response.get("Contents")
        if contents:
            first_obj = {
                "key": contents[0].get("Key"),
                "size": contents[0].get("Size"),
                "last_modified": contents[0].get("LastModified").isoformat()
                if contents[0].get("LastModified")
                else None,
            }
        diagnostics["s3_check"]["first_object"] = first_obj
    except Exception as exc:  # pylint: disable=broad-except
        diagnostics["s3_check"] = {
            "request": {
                "bucket": bucket,
                "prefix": prefix,
                "max_keys": 1,
            },
            "status": "error",
            "error": str(exc),
        }


def ensure_pyarrow_available() -> None:
    if PYARROW_IMPORT_ERROR is not None:
        raise RuntimeError(
            "pyarrow failed to import: {}. Review deployment artifacts or rebuild for the correct architecture.".format(
                PYARROW_IMPORT_ERROR
            )
        )


__all__ = [
    "lambda_handler",
    "extract_s3_references",
    "build_arrow_table_from_s3_objects",
    "load_json_lines_as_table",
    "table_to_parquet",
    "insert_into_clickhouse",
    "collect_runtime_diagnostics",
    "env_flag",
    "ensure_pyarrow_available",
]
