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
CLICKHOUSE_PROTOCOL        "https" | "http" (defaults to http)
CLICKHOUSE_PATH            Optional URL path suffix (e.g. /custom/endpoint)
CLICKHOUSE_DATABASE        Target database (required when using host/port form)
CLICKHOUSE_TABLE           Target table (required when using host/port form)
CLICKHOUSE_INSERT_SQL      Full INSERT statement override (optional)
CLICKHOUSE_INSERT_COLUMNS  Comma separated column projection for inserts (optional)
CLICKHOUSE_USER            Basic auth user (optional)
CLICKHOUSE_PASSWORD        Basic auth password (optional)
CLICKHOUSE_SETTINGS        Comma separated ClickHouse setting overrides
PARQUET_COMPRESSION        Compression codec (defaults to snappy)
CLICKHOUSE_TIMEOUT_SECONDS Request timeout for HTTP insert (default 30)
MAX_S3_OBJECT_BYTES        Soft cap per S3 object (bytes); raises if exceeded
FAILURE_DLQ_URL            Optional SQS queue URL for permanently failed messages

The handler returns the partial batch response structure required for SQS event
source mappings with the "ReportBatchItemFailures" feature.
"""
from __future__ import annotations

import hashlib
import importlib
import io
import json
import logging
import math
import os
import platform
import time
import sys
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import unquote_plus, urlparse

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


_FAILURE_DLQ_URL = os.getenv("FAILURE_DLQ_URL")
_sqs_client = boto3.client("sqs") if _FAILURE_DLQ_URL else None


# Column order for the unified raw_events table as defined in
# priv/clickhouse/migrations/20250909000001_create_raw_events.sql. Columns with
# ClickHouse defaults (e.g., inserted_at, event_version) are intentionally
# omitted so the server supplies those values automatically.
DEFAULT_CLICKHOUSE_INSERT_COLUMNS: List[str] = [
    "event_id",
    "user_id",
    "host_name",
    "section_id",
    "project_id",
    "publication_id",
    "timestamp",
    "event_type",
    "page_id",
    "content_element_id",
    "video_url",
    "video_time",
    "video_length",
    "video_progress",
    "video_played_segments",
    "video_play_time",
    "video_seek_from",
    "video_seek_to",
    "activity_attempt_guid",
    "activity_attempt_number",
    "page_attempt_guid",
    "page_attempt_number",
    "part_attempt_guid",
    "part_attempt_number",
    "activity_id",
    "activity_revision_id",
    "part_id",
    "page_sub_type",
    "score",
    "out_of",
    "scaled_score",
    "success",
    "completion",
    "response",
    "feedback",
    "hints_requested",
    "attached_objectives",
    "session_id",
    "event_hash",
    "source_file",
    "source_etag",
    "source_line",
]

_CLICKHOUSE_TYPE_MAP: Optional[Dict[str, "pa.DataType"]] = None


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
    failed_message_ids: List[str] = []
    total_rows = 0
    total_objects = 0
    dry_run_enabled = env_flag("DRY_RUN", default=False)

    for record in records:
        message_id = record.get("messageId", "<unknown>")
        logger.info("Processing message %s", message_id)
        try:
            if is_s3_test_event(record):
                logger.info(
                    "Message %s is an S3 test event; acknowledging without processing",
                    message_id,
                )
                empty_message_ids.append(message_id)
                continue

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
            logger.error(
                "Message %s moved to DLQ (if configured); inspect the DLQ for full payload and reason details",
                message_id,
            )
            forward_failure_to_dlq(record, reason=str(exc))
            # Simple debug using repr to produce a safe string representation
            logger.debug("SQS record for message %s: %r", message_id, record)
            logger.debug("Full Lambda event: %r", event)

            failed_message_ids.append(message_id)
            continue

        logger.info("Message %s prepared successfully", message_id)

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
            for message_id in message_ids_for_insert:
                forward_failure_to_dlq(find_record_by_id(records, message_id), reason=str(exc))
            failed_message_ids.extend(message_ids_for_insert)

    unique_failures = sorted(set(failed_message_ids))
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


def is_s3_test_event(record: Dict[str, Any]) -> bool:
    """Return True when the record is an S3 TestEvent notification."""
    body = record.get("body")
    if not body:
        return False
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return False
    return (
        isinstance(payload, dict)
        and payload.get("Service") == "Amazon S3"
        and payload.get("Event") == "s3:TestEvent"
    )


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


def forward_failure_to_dlq(record: Optional[Dict[str, Any]], *, reason: str) -> None:
    """Send irrecoverable messages to an optional DLQ for later triage."""
    if not _sqs_client or not _FAILURE_DLQ_URL or not record:
        return

    message_body = record.get("body") if isinstance(record, dict) else None
    message_id = record.get("messageId") if isinstance(record, dict) else None
    attributes = {
        "OriginalMessageId": {
            "DataType": "String",
            "StringValue": message_id or "",
        },
        "FailureReason": {
            "DataType": "String",
            "StringValue": reason[:256],
        },
    }
    try:
        _sqs_client.send_message(
            QueueUrl=_FAILURE_DLQ_URL,
            MessageBody=message_body or "",
            MessageAttributes=attributes,
        )
        logger.info("Forwarded message %s to DLQ", message_id or "<unknown>")
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("Failed to send message %s to DLQ: %s", message_id or "<unknown>", exc)


def find_record_by_id(records: Iterable[Dict[str, Any]], message_id: str) -> Optional[Dict[str, Any]]:
    """Locate a record by messageId for DLQ forwarding on batch insert failures."""
    for record in records:
        if record.get("messageId") == message_id:
            return record
    return None


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

    processed_rows = 0

    for physical_line, raw_line in enumerate(body.iter_lines(chunk_size=1024 * 64), start=1):
        if not raw_line:
            continue
        try:
            statement = json.loads(raw_line)
            processed_rows += 1
            transformed = transform_xapi_statement(
                statement,
                raw_bytes=raw_line,
                bucket=ref.bucket,
                key=ref.key,
                etag=response.get("ETag"),
                line_number=processed_rows,
            )
            rows.append(transformed)
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Invalid JSON in s3://{ref.bucket}/{ref.key}: {raw_line[:200]!r}"
            ) from exc
        except Exception as exc:  # pylint: disable=broad-except
            raise ValueError(
                f"Failed to transform JSON in s3://{ref.bucket}/{ref.key}: line {physical_line}"
            ) from exc

        now = time.perf_counter()
        if now >= next_log_deadline:
            logger.debug(
                "Read %d lines (%d statements) from s3://%s/%s (%.2fs elapsed)",
                physical_line,
                processed_rows,
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
        table = normalize_table_schema(table)
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


def normalize_table_schema(table: pa.Table) -> pa.Table:
    """Apply predictable type conversions before writing to Parquet."""
    ensure_pyarrow_available()

    timestamp_idx = table.schema.get_field_index("timestamp")
    if timestamp_idx != -1:
        column = table.column(timestamp_idx)
        if pa.types.is_string(column.type):
            try:
                converted = _coerce_iso8601_timestamp_column(column)
                field = table.schema.field(timestamp_idx).with_type(converted.type)
                table = table.set_column(timestamp_idx, field, converted)
            except Exception as exc:  # pylint: disable=broad-except
                logger.warning(
                    "Failed to coerce timestamp column to Arrow timestamp: %s",
                    exc,
                )
    return _project_table_to_clickhouse_columns(table)


def _coerce_iso8601_timestamp_column(column: pa.ChunkedArray) -> pa.Array:
    ensure_pyarrow_available()
    values = column.to_pylist()
    parsed: List[Optional[datetime]] = []
    for raw in values:
        if raw is None:
            parsed.append(None)
            continue
        parsed.append(_parse_iso8601_timestamp(raw))

    # Normalize everything to UTC millisecond precision to match ClickHouse DateTime64(3)
    return pa.array(parsed, type=pa.timestamp("ms", tz="UTC"))


def _parse_iso8601_timestamp(raw: Any) -> datetime:
    if isinstance(raw, datetime):
        dt = raw
    else:
        if not isinstance(raw, str):
            raise TypeError(f"Unsupported timestamp value type: {type(raw)!r}")
        text = raw.strip()
        if not text:
            raise ValueError("Empty timestamp string")
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"

        try:
            dt = datetime.fromisoformat(text)
        except ValueError as exc:
            dot_index = text.find(".")
            if dot_index != -1:
                tz_start = max(text.find("+", dot_index), text.find("-", dot_index))
                if tz_start == -1:
                    tz_start = len(text)
                fractional = text[dot_index + 1 : tz_start]
                if fractional and len(fractional) > 6:
                    trimmed = text[: dot_index + 1] + fractional[:6] + text[tz_start:]
                    dt = datetime.fromisoformat(trimmed)
                else:
                    raise ValueError(f"Invalid ISO-8601 timestamp: {text}") from exc
            else:
                raise ValueError(f"Invalid ISO-8601 timestamp: {text}") from exc

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)

    return dt.astimezone(timezone.utc)


def _project_table_to_clickhouse_columns(table: pa.Table) -> pa.Table:
    columns = resolve_clickhouse_insert_columns()
    if not columns:
        return table

    type_map = _get_clickhouse_type_map()
    arrays = []
    names: List[str] = []
    row_count = table.num_rows

    for column_name in columns:
        expected_type = type_map.get(column_name)
        if column_name in table.schema.names:
            column = table.column(column_name)
            if expected_type is not None and not column.type.equals(expected_type):
                try:
                    column = column.cast(expected_type)
                except Exception as exc:  # pylint: disable=broad-except
                    raise ValueError(
                        f"Column '{column_name}' cannot be cast from {column.type} to {expected_type}"
                    ) from exc
            arrays.append(column)
        else:
            if expected_type is None:
                raise ValueError(
                    f"Missing ClickHouse column '{column_name}' and no type information available"
                )
            logger.debug(
                "Filling missing ClickHouse column '%s' with NULL values (expected type %s)",
                column_name,
                expected_type,
            )
            arrays.append(pa.nulls(row_count, type=expected_type))
        names.append(column_name)

    return pa.Table.from_arrays(arrays, names=names)


def _get_clickhouse_type_map() -> Dict[str, "pa.DataType"]:
    ensure_pyarrow_available()
    global _CLICKHOUSE_TYPE_MAP  # noqa: PLW0603 -- module level cache for performance
    if _CLICKHOUSE_TYPE_MAP is None:
        _CLICKHOUSE_TYPE_MAP = {
            "event_id": pa.string(),
            "user_id": pa.string(),
            "host_name": pa.string(),
            "section_id": pa.uint64(),
            "project_id": pa.uint64(),
            "publication_id": pa.uint64(),
            "timestamp": pa.timestamp("ms", tz="UTC"),
            "event_type": pa.string(),
            "page_id": pa.uint64(),
            "content_element_id": pa.string(),
            "video_url": pa.string(),
            "video_time": pa.float64(),
            "video_length": pa.float64(),
            "video_progress": pa.float64(),
            "video_played_segments": pa.string(),
            "video_play_time": pa.float64(),
            "video_seek_from": pa.float64(),
            "video_seek_to": pa.float64(),
            "activity_attempt_guid": pa.string(),
            "activity_attempt_number": pa.uint32(),
            "page_attempt_guid": pa.string(),
            "page_attempt_number": pa.uint32(),
            "part_attempt_guid": pa.string(),
            "part_attempt_number": pa.uint32(),
            "activity_id": pa.uint64(),
            "activity_revision_id": pa.uint64(),
            "part_id": pa.string(),
            "page_sub_type": pa.string(),
            "score": pa.float64(),
            "out_of": pa.float64(),
            "scaled_score": pa.float64(),
            "success": pa.bool_(),
            "completion": pa.bool_(),
            "response": pa.string(),
            "feedback": pa.string(),
            "hints_requested": pa.uint32(),
            "attached_objectives": pa.string(),
            "session_id": pa.string(),
            "event_hash": pa.string(),
            "source_file": pa.string(),
            "source_etag": pa.string(),
            "source_line": pa.uint32(),
        }
    return _CLICKHOUSE_TYPE_MAP


def transform_xapi_statement(
    statement: Dict[str, Any],
    *,
    raw_bytes: bytes,
    bucket: str,
    key: str,
    etag: Optional[str],
    line_number: int,
) -> Dict[str, Any]:
    """Map an xAPI statement into the raw_events column structure."""

    context = statement.get("context", {}) or {}
    extensions = context.get("extensions", {}) or {}
    actor = statement.get("actor", {}) or {}
    account = actor.get("account", {}) or {}
    verb = statement.get("verb", {}) or {}
    result = statement.get("result", {}) or {}
    result_extensions = result.get("extensions", {}) or {}
    obj = statement.get("object", {}) or {}
    object_definition = obj.get("definition", {}) or {}
    object_extensions = object_definition.get("extensions", {}) or {}

    timestamp_raw = statement.get("timestamp")
    if not isinstance(timestamp_raw, str) or not timestamp_raw.strip():
        timestamp_raw = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    verb_id = verb.get("id", "") or ""
    object_type = object_definition.get("type", "") or ""
    event_type = _determine_event_type(verb_id, object_type)

    event_id = statement.get("id") or statement.get("event_id") or str(uuid.uuid4())
    event_id = str(event_id)

    user_id = account.get("name") or actor.get("mbox") or ""
    if not isinstance(user_id, str):
        user_id = str(user_id)

    host_name = extensions.get("http://oli.cmu.edu/extensions/host_name")
    if not host_name:
        home_page = account.get("homePage")
        if isinstance(home_page, str):
            host_name = _extract_hostname(home_page)
        if not host_name:
            object_id = obj.get("id")
            if isinstance(object_id, str):
                host_name = _extract_hostname(object_id)
    if host_name is not None and not isinstance(host_name, str):
        host_name = str(host_name)

    section_id = _safe_int(extensions.get("http://oli.cmu.edu/extensions/section_id"))
    project_id = _safe_int(extensions.get("http://oli.cmu.edu/extensions/project_id"))
    publication_id = _safe_int(extensions.get("http://oli.cmu.edu/extensions/publication_id"))

    content_element_id = (
        result_extensions.get("content_element_id")
        or extensions.get("http://oli.cmu.edu/extensions/content_element_id")
    )
    if content_element_id is not None and not isinstance(content_element_id, str):
        content_element_id = str(content_element_id)

    video_url = obj.get("id") if event_type == "video" else None
    if video_url is not None and not isinstance(video_url, str):
        video_url = str(video_url)

    video_played_segments = result_extensions.get(
        "https://w3id.org/xapi/video/extensions/played-segments"
    )
    if video_played_segments is not None and not isinstance(video_played_segments, str):
        video_played_segments = json.dumps(video_played_segments)

    activity_attempt_guid = extensions.get("http://oli.cmu.edu/extensions/activity_attempt_guid")
    if activity_attempt_guid is not None and not isinstance(activity_attempt_guid, str):
        activity_attempt_guid = str(activity_attempt_guid)

    page_attempt_guid = extensions.get("http://oli.cmu.edu/extensions/page_attempt_guid")
    if page_attempt_guid is not None and not isinstance(page_attempt_guid, str):
        page_attempt_guid = str(page_attempt_guid)

    part_attempt_guid = extensions.get("http://oli.cmu.edu/extensions/part_attempt_guid")
    if part_attempt_guid is not None and not isinstance(part_attempt_guid, str):
        part_attempt_guid = str(part_attempt_guid)

    part_id = extensions.get("http://oli.cmu.edu/extensions/part_id")
    if part_id is not None and not isinstance(part_id, str):
        part_id = str(part_id)

    session_id = extensions.get("http://oli.cmu.edu/extensions/session_id")
    if session_id is not None and not isinstance(session_id, str):
        session_id = str(session_id)

    feedback = result_extensions.get("http://oli.cmu.edu/extensions/feedback")
    if feedback is not None and not isinstance(feedback, str):
        feedback = json.dumps(feedback)

    response_value = result.get("response")
    if isinstance(response_value, dict):
        response_value = response_value.get("input") or json.dumps(response_value)
    elif response_value is not None and not isinstance(response_value, str):
        response_value = str(response_value)

    attached_objectives = extensions.get("http://oli.cmu.edu/extensions/attached_objectives")
    if attached_objectives is not None and not isinstance(attached_objectives, str):
        attached_objectives = json.dumps(attached_objectives)

    hints_requested = extensions.get("http://oli.cmu.edu/extensions/hints_requested")
    if isinstance(hints_requested, list):
        hints_requested_value: Optional[int] = len(hints_requested)
    else:
        hints_requested_value = _safe_int(hints_requested)

    raw_hash = hashlib.sha256(raw_bytes).hexdigest()

    transformed: Dict[str, Any] = {
        "event_id": event_id,
        "user_id": user_id,
        "host_name": host_name or "",
        "section_id": section_id,
        "project_id": project_id,
        "publication_id": publication_id,
        "timestamp": timestamp_raw,
        "event_type": event_type,
        "page_id": _safe_int(extensions.get("http://oli.cmu.edu/extensions/page_id")),
        "content_element_id": content_element_id,
        "video_url": video_url,
        "video_time": _safe_float(result_extensions.get("https://w3id.org/xapi/video/extensions/time")),
        "video_length": _safe_float(
            result_extensions.get("https://w3id.org/xapi/video/extensions/length")
            or extensions.get("https://w3id.org/xapi/video/extensions/length")
            or object_extensions.get("https://w3id.org/xapi/video/extensions/length")
        ),
        "video_progress": _safe_float(
            result_extensions.get("https://w3id.org/xapi/video/extensions/progress")
        ),
        "video_played_segments": video_played_segments,
        "video_play_time": _safe_float(result_extensions.get("video_play_time")),
        "video_seek_from": _safe_float(
            result_extensions.get("https://w3id.org/xapi/video/extensions/time-from")
        ),
        "video_seek_to": _safe_float(
            result_extensions.get("https://w3id.org/xapi/video/extensions/time-to")
        ),
        "activity_attempt_guid": activity_attempt_guid,
        "activity_attempt_number": _safe_int(
            extensions.get("http://oli.cmu.edu/extensions/activity_attempt_number")
        ),
        "page_attempt_guid": page_attempt_guid,
        "page_attempt_number": _safe_int(
            extensions.get("http://oli.cmu.edu/extensions/page_attempt_number")
        ),
        "part_attempt_guid": part_attempt_guid,
        "part_attempt_number": _safe_int(
            extensions.get("http://oli.cmu.edu/extensions/part_attempt_number")
        ),
        "activity_id": _safe_int(extensions.get("http://oli.cmu.edu/extensions/activity_id")),
        "activity_revision_id": _safe_int(
            extensions.get("http://oli.cmu.edu/extensions/activity_revision_id")
        ),
        "part_id": part_id,
        "page_sub_type": object_definition.get("subType"),
        "score": _safe_float(_get_nested(result, ["score", "raw"])),
        "out_of": _safe_float(_get_nested(result, ["score", "max"])),
        "scaled_score": _safe_float(_get_nested(result, ["score", "scaled"])),
        "success": _coerce_bool(result.get("success")),
        "completion": _coerce_bool(result.get("completion")),
        "response": response_value,
        "feedback": feedback,
        "hints_requested": hints_requested_value,
        "attached_objectives": attached_objectives,
        "session_id": session_id,
        "event_hash": raw_hash,
        "source_file": f"s3://{bucket}/{key}",
        "source_etag": etag.strip('"') if isinstance(etag, str) else etag,
        "source_line": line_number,
    }

    return transformed


def _determine_event_type(verb_id: str, object_type: str) -> str:
    verb_id = verb_id or ""
    object_type = object_type or ""

    video_verbs = {
        "https://w3id.org/xapi/video/verbs/played",
        "https://w3id.org/xapi/video/verbs/paused",
        "https://w3id.org/xapi/video/verbs/seeked",
        "https://w3id.org/xapi/video/verbs/completed",
        "http://adlnet.gov/expapi/verbs/experienced",
    }
    if verb_id in video_verbs:
        return "video"
    if (
        verb_id == "http://adlnet.gov/expapi/verbs/completed"
        and object_type == "http://oli.cmu.edu/extensions/activity_attempt"
    ):
        return "activity_attempt"
    if (
        verb_id == "http://adlnet.gov/expapi/verbs/completed"
        and object_type == "http://oli.cmu.edu/extensions/page_attempt"
    ):
        return "page_attempt"
    if (
        verb_id == "http://id.tincanapi.com/verb/viewed"
        and object_type == "http://oli.cmu.edu/extensions/types/page"
    ):
        return "page_viewed"
    if (
        verb_id == "http://adlnet.gov/expapi/verbs/completed"
        and object_type == "http://adlnet.gov/expapi/activities/question"
    ):
        return "part_attempt"
    return "unknown"


def _safe_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int,)):
        return value
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return None
        return int(value)
    if isinstance(value, str):
        try:
            if "." in value:
                return int(float(value))
            return int(value)
        except ValueError:
            return None
    try:
        return int(value)  # type: ignore[arg-type]
    except Exception:  # pylint: disable=broad-except
        return None


def _safe_float(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return float(value)
    if isinstance(value, (int, float)):
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return None
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    try:
        return float(value)  # type: ignore[arg-type]
    except Exception:  # pylint: disable=broad-except
        return None


def _coerce_bool(value: Any) -> Optional[bool]:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "1", "t", "yes", "y"}:
            return True
        if normalized in {"false", "0", "f", "no", "n"}:
            return False
    return None


def _get_nested(data: Any, path: List[str]) -> Any:
    current = data
    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
        if current is None:
            return None
    return current


def _extract_hostname(url: str) -> Optional[str]:
    try:
        parsed = urlparse(url)
        if parsed.hostname:
            return parsed.hostname
        if parsed.path and "://" not in url:
            return parsed.path.split("/")[0]
        return None
    except Exception:  # pylint: disable=broad-except
        return None


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

    protocol_override = os.getenv("CLICKHOUSE_PROTOCOL")
    secure_env = os.getenv("CLICKHOUSE_SECURE")
    port_env = os.getenv("CLICKHOUSE_PORT")

    if protocol_override:
        protocol = protocol_override.lower()
        secure = protocol == "https"
    else:
        if secure_env is not None:
            secure = secure_env.lower() == "true"
        else:
            secure = port_env not in {None, "80", "8123"}
        protocol = "https" if secure else "http"

    default_port = "8443" if protocol == "https" else "8123"
    port = port_env or default_port

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
    columns = resolve_clickhouse_insert_columns()
    column_clause = ""
    if columns:
        column_clause = " (" + ", ".join(quote_identifier(col) for col in columns) + ")"

    return (
        f"INSERT INTO {quote_identifier(database)}.{quote_identifier(table)}"
        f"{column_clause} FORMAT Parquet"
    )


def quote_identifier(identifier: str) -> str:
    return f"`{identifier.replace('`', '``')}`"


def resolve_clickhouse_insert_columns() -> List[str]:
    env_value = os.getenv("CLICKHOUSE_INSERT_COLUMNS")
    if env_value is not None:
        parsed = [item.strip() for item in env_value.split(",") if item.strip()]
        if parsed and parsed != ["*"]:
            return parsed
        if parsed == ["*"]:
            return []
        if not parsed:
            # Explicitly set to empty string → disable column projection
            return []
    return DEFAULT_CLICKHOUSE_INSERT_COLUMNS


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
    "transform_xapi_statement",
]
