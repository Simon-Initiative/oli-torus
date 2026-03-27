import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest import SkipTest, TestCase, mock

try:
    import pytest
except ModuleNotFoundError:  # pragma: no cover - local fallback when pytest is absent
    class _PytestShim:
        @staticmethod
        def skip(message, allow_module_level=False):
            raise SkipTest(message)

    pytest = _PytestShim()

try:
    import pyarrow  # noqa: F401
except ModuleNotFoundError:
    pytest.skip("pyarrow is required for these tests; install it or run under Python 3.11", allow_module_level=True)

MODULE_PATH = Path(__file__).resolve().parents[1] / "lambda_function.py"
spec = importlib.util.spec_from_file_location("lambda_function", MODULE_PATH)
lambda_function = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = lambda_function
spec.loader.exec_module(lambda_function)  # type: ignore[misc]


class FakeBody:
    def __init__(self, lines):
        self._lines = [line.encode("utf-8") for line in lines]

    def iter_lines(self, chunk_size=None):  # chunk_size kept for compatibility
        for line in self._lines:
            yield line


class FakeContext:
    def __init__(self, remaining_time_ms=None):
        self.remaining_time_ms = remaining_time_ms

    def get_remaining_time_in_millis(self):
        if self.remaining_time_ms is None:
            raise RuntimeError("remaining time not configured")
        return self.remaining_time_ms


class LambdaFunctionTests(TestCase):
    def setUp(self):
        patcher = mock.patch.object(lambda_function, "s3_client")
        self.addCleanup(patcher.stop)
        self.mock_s3 = patcher.start()
        for env_var in [
            "DRY_RUN",
            "TARGET_ROWS_PER_INSERT",
            "MAX_ROWS_PER_INSERT",
            "MAX_PARQUET_BYTES_PER_INSERT",
            "MIN_REMAINING_TIME_TO_START_INSERT_MS",
            "LAMBDA_TIMEOUT_SAFETY_MARGIN_MS",
            "CLICKHOUSE_TIMEOUT_SECONDS",
            "MAX_MESSAGES_PER_INVOCATION_TO_PROCESS",
        ]:
            self.addCleanup(lambda name=env_var: os.environ.pop(name, None))

    def _message(self, message_id):
        body = json.dumps({"bucket": "bucket", "key": f"events/{message_id}.jsonl"})
        return {"messageId": message_id, "body": body}

    def _table_with_rows(self, row_count):
        return lambda_function.pa.Table.from_pylist(
            [{"event_hash": f"hash-{index}", "source_line": index + 1} for index in range(row_count)]
        )

    def test_extract_s3_references_from_event(self):
        event = {
            "Records": [
                {
                    "s3": {
                        "bucket": {"name": "bucket"},
                        "object": {"key": "path/to/file.jsonl"},
                    }
                }
            ]
        }

        refs = list(lambda_function._extract_from_s3_event_record(event["Records"][0]))
        self.assertEqual(len(refs), 1)
        self.assertEqual(refs[0].bucket, "bucket")
        self.assertEqual(refs[0].key, "path/to/file.jsonl")

    def test_lambda_handler_successful_batch(self):
        body = json.dumps(
            {
                "Records": [
                    {
                        "s3": {
                            "bucket": {"name": "bucket"},
                            "object": {"key": "events/file.jsonl"},
                        }
                    }
                ]
            }
        )
        event = {
            "Records": [
                {
                    "messageId": "msg-1",
                    "body": body,
                }
            ]
        }

        self.mock_s3.get_object.return_value = {
            "Body": FakeBody(['{"user": "alice"}'])
        }

        with mock.patch.object(lambda_function, "insert_into_clickhouse") as insert_mock:
            with mock.patch.dict(
                os.environ,
                {
                    "CLICKHOUSE_DATABASE": "db",
                    "CLICKHOUSE_TABLE": "tbl",
                    "TARGET_ROWS_PER_INSERT": "10",
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [])
        insert_mock.assert_called_once()
        args, kwargs = insert_mock.call_args
        self.assertGreater(len(args[0]), 0)  # parquet payload bytes
        self.assertEqual(args[1], 1)
        self.assertIn("timeout_seconds", kwargs)
        self.assertIn("insert_token", kwargs)

    def test_lambda_handler_respects_dry_run(self):
        body = json.dumps(
            {
                "Records": [
                    {
                        "s3": {
                            "bucket": {"name": "bucket"},
                            "object": {"key": "events/file.jsonl"},
                        }
                    }
                ]
            }
        )
        event = {
            "Records": [
                {
                    "messageId": "msg-1",
                    "body": body,
                }
            ]
        }

        self.mock_s3.get_object.return_value = {
            "Body": FakeBody(['{"user": "alice"}'])
        }

        os.environ["DRY_RUN"] = "true"

        with mock.patch.object(lambda_function, "insert_into_clickhouse") as insert_mock:
            with mock.patch.dict(
                os.environ,
                {
                    "CLICKHOUSE_DATABASE": "db",
                    "CLICKHOUSE_TABLE": "tbl",
                    "TARGET_ROWS_PER_INSERT": "10",
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [])
        insert_mock.assert_not_called()

    def test_lambda_handler_returns_failure_on_bad_json(self):
        body = json.dumps(
            {
                "Records": [
                    {
                        "s3": {
                            "bucket": {"name": "bucket"},
                            "object": {"key": "events/file.jsonl"},
                        }
                    }
                ]
            }
        )
        event = {
            "Records": [
                {
                    "messageId": "msg-1",
                    "body": body,
                }
            ]
        }

        self.mock_s3.get_object.return_value = {
            "Body": FakeBody(['{"user": }'])
        }

        with mock.patch.object(lambda_function, "insert_into_clickhouse") as insert_mock:
            with mock.patch.dict(
                os.environ,
                {
                    "CLICKHOUSE_DATABASE": "db",
                    "CLICKHOUSE_TABLE": "tbl",
                    "TARGET_ROWS_PER_INSERT": "10",
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [
            {"itemIdentifier": "msg-1"}
        ])
        insert_mock.assert_not_called()

    def test_load_json_lines_assigns_sequential_source_line_numbers(self):
        statements = [
            {"id": "evt-1", "actor": {"account": {"name": "alice"}}},
            {"id": "evt-2", "actor": {"account": {"name": "bob"}}},
        ]

        payload_lines = ["", "", *(json.dumps(item) for item in statements)]
        self.mock_s3.get_object.return_value = {
            "Body": FakeBody(payload_lines),
            "ETag": '"etag-value"',
        }

        table = lambda_function.load_json_lines_as_table(
            lambda_function.S3ObjectRef(bucket="bucket", key="events/file.jsonl")
        )

        self.assertIsNotNone(table)
        source_lines = table.column("source_line").to_pylist()
        self.assertEqual(source_lines, [1, 2])

    def test_lambda_handler_sends_failed_prepare_to_dlq(self):
        body = json.dumps({"bucket": "bucket", "key": "events/file.jsonl"})
        event = {
            "Records": [
                {
                    "messageId": "msg-1",
                    "body": body,
                }
            ]
        }

        with mock.patch.object(lambda_function, "_FAILURE_DLQ_URL", "https://example.com/dlq"):
            with mock.patch.object(lambda_function, "_sqs_client") as sqs_mock:
                with mock.patch.object(
                    lambda_function,
                    "extract_s3_references",
                    side_effect=ValueError("bad payload"),
                ):
                    with mock.patch.dict(
                        os.environ,
                        {
                            "CLICKHOUSE_DATABASE": "db",
                            "CLICKHOUSE_TABLE": "tbl",
                            "TARGET_ROWS_PER_INSERT": "10",
                        },
                        clear=False,
                    ):
                        result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "msg-1"}])
        sqs_mock.send_message.assert_called_once()
        call = sqs_mock.send_message.call_args.kwargs
        self.assertEqual(call["QueueUrl"], "https://example.com/dlq")
        self.assertEqual(json.loads(call["MessageBody"]), json.loads(body))
        self.assertIn("FailureReason", call["MessageAttributes"])

    def test_lambda_handler_logs_bounded_info_on_prepare_failure(self):
        record_payload = {
            "bucket": "bucket",
            "key": "events/file.jsonl",
            "debug_blob": "SECRET_PAYLOAD_" * 20,
        }
        body = json.dumps(record_payload)
        event = {"Records": [{"messageId": "msg-1", "body": body}]}

        with mock.patch.object(
            lambda_function,
            "extract_s3_references",
            side_effect=ValueError("bad payload"),
        ):
            with mock.patch.dict(
                os.environ,
                {
                    "CLICKHOUSE_DATABASE": "db",
                    "CLICKHOUSE_TABLE": "tbl",
                    "TARGET_ROWS_PER_INSERT": "10",
                },
                clear=False,
            ):
                with self.assertLogs(lambda_function.logger, level="INFO") as captured_logs:
                    result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "msg-1"}])
        joined_logs = "\n".join(captured_logs.output)
        self.assertIn("Failed to prepare SQS message msg-1: bad payload", joined_logs)
        self.assertIn(
            "Message msg-1 moved to DLQ (if configured); inspect the DLQ for full payload and reason details",
            joined_logs,
        )
        self.assertNotIn(record_payload["debug_blob"], joined_logs)
        self.assertNotIn(body, joined_logs)

    def test_forward_failure_to_dlq_sends_summary_attributes(self):
        body = json.dumps({"bucket": "bucket", "key": "events/file.jsonl"})
        record = {"messageId": "msg-1", "body": body}
        long_reason = "x" * 400

        with mock.patch.object(lambda_function, "_FAILURE_DLQ_URL", "https://example.com/dlq"):
            with mock.patch.object(lambda_function, "_sqs_client") as sqs_mock:
                lambda_function.forward_failure_to_dlq(record, reason=long_reason)

        sqs_mock.send_message.assert_called_once()
        call = sqs_mock.send_message.call_args.kwargs
        self.assertEqual(call["QueueUrl"], "https://example.com/dlq")
        self.assertEqual(call["MessageBody"], body)
        self.assertEqual(
            set(call["MessageAttributes"].keys()),
            {"OriginalMessageId", "FailureReason"},
        )
        self.assertEqual(
            call["MessageAttributes"]["OriginalMessageId"]["StringValue"],
            "msg-1",
        )
        self.assertEqual(
            call["MessageAttributes"]["FailureReason"]["StringValue"],
            long_reason[:256],
        )

    def test_lambda_handler_retries_clickhouse_failures_without_dlq_copy(self):
        event = {"Records": [self._message("msg-1"), self._message("msg-2")]}

        with mock.patch.object(lambda_function, "_FAILURE_DLQ_URL", "https://example.com/dlq"):
            with mock.patch.object(lambda_function, "_sqs_client") as sqs_mock:
                with mock.patch.object(
                    lambda_function,
                    "build_arrow_table_from_s3_objects",
                    side_effect=[self._table_with_rows(2), self._table_with_rows(2)],
                ):
                    with mock.patch.object(
                        lambda_function,
                        "insert_into_clickhouse",
                        side_effect=RuntimeError("ClickHouse down"),
                    ):
                        with mock.patch.dict(
                            os.environ,
                            {
                                "CLICKHOUSE_DATABASE": "db",
                                "CLICKHOUSE_TABLE": "tbl",
                                "TARGET_ROWS_PER_INSERT": "4",
                            },
                            clear=False,
                        ):
                            result = lambda_function.lambda_handler(
                                event,
                                FakeContext(remaining_time_ms=60000),
                            )

        self.assertEqual(
            result["batchItemFailures"],
            [{"itemIdentifier": "msg-1"}, {"itemIdentifier": "msg-2"}],
        )
        sqs_mock.send_message.assert_not_called()

    def test_lambda_handler_flushes_multiple_sub_batches(self):
        event = {
            "Records": [self._message("msg-1"), self._message("msg-2"), self._message("msg-3")]
        }

        insert_calls = []

        def capture_insert(_payload, row_count, **kwargs):
            insert_calls.append((row_count, kwargs))

        with mock.patch.object(
            lambda_function,
            "build_arrow_table_from_s3_objects",
            side_effect=[
                self._table_with_rows(2),
                self._table_with_rows(2),
                self._table_with_rows(2),
            ],
        ):
            with mock.patch.object(lambda_function, "insert_into_clickhouse", side_effect=capture_insert):
                with mock.patch.dict(
                    os.environ,
                    {
                        "CLICKHOUSE_DATABASE": "db",
                        "CLICKHOUSE_TABLE": "tbl",
                        "TARGET_ROWS_PER_INSERT": "4",
                        "MAX_ROWS_PER_INSERT": "6",
                    },
                    clear=False,
                ):
                    result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [])
        self.assertEqual([call[0] for call in insert_calls], [4, 2])
        self.assertTrue(all("insert_token" in kwargs for _, kwargs in insert_calls))

    def test_lambda_handler_retries_only_failed_sub_batch(self):
        event = {
            "Records": [self._message("msg-1"), self._message("msg-2"), self._message("msg-3")]
        }

        with mock.patch.object(
            lambda_function,
            "build_arrow_table_from_s3_objects",
            side_effect=[
                self._table_with_rows(2),
                self._table_with_rows(2),
                self._table_with_rows(2),
            ],
        ):
            with mock.patch.object(
                lambda_function,
                "insert_into_clickhouse",
                side_effect=[None, RuntimeError("ClickHouse down")],
            ):
                with mock.patch.dict(
                    os.environ,
                    {
                        "CLICKHOUSE_DATABASE": "db",
                        "CLICKHOUSE_TABLE": "tbl",
                        "TARGET_ROWS_PER_INSERT": "4",
                        "MAX_ROWS_PER_INSERT": "6",
                    },
                    clear=False,
                ):
                    result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "msg-3"}])

    def test_lambda_handler_emits_no_progress_and_returns_prepared_and_untouched_messages(self):
        event = {"Records": [self._message("msg-1"), self._message("msg-2")]}
        context = FakeContext(remaining_time_ms=2000)

        def prepare_then_exhaust_time(_refs):
            context.remaining_time_ms = 500
            return self._table_with_rows(2)

        with mock.patch.object(
            lambda_function,
            "build_arrow_table_from_s3_objects",
            side_effect=prepare_then_exhaust_time,
        ):
            with mock.patch.object(lambda_function, "insert_into_clickhouse") as insert_mock:
                with mock.patch.dict(
                    os.environ,
                    {
                        "CLICKHOUSE_DATABASE": "db",
                        "CLICKHOUSE_TABLE": "tbl",
                        "MIN_REMAINING_TIME_TO_START_INSERT_MS": "1000",
                    },
                    clear=False,
                ):
                    with self.assertLogs(lambda_function.logger, level="INFO") as captured_logs:
                        result = lambda_function.lambda_handler(event, context)

        self.assertEqual(
            result["batchItemFailures"],
            [{"itemIdentifier": "msg-1"}, {"itemIdentifier": "msg-2"}],
        )
        insert_mock.assert_not_called()
        self.assertTrue(any("sub_batch_no_progress" in line for line in captured_logs.output))

    def test_lambda_handler_logs_last_successful_stage_before_insert_failure(self):
        event = {"Records": [self._message("msg-1")]}

        with mock.patch.object(
            lambda_function,
            "build_arrow_table_from_s3_objects",
            return_value=self._table_with_rows(2),
        ):
            with mock.patch.object(
                lambda_function,
                "insert_into_clickhouse",
                side_effect=RuntimeError("ClickHouse down"),
            ):
                with mock.patch.dict(
                    os.environ,
                    {
                        "CLICKHOUSE_DATABASE": "db",
                        "CLICKHOUSE_TABLE": "tbl",
                        "TARGET_ROWS_PER_INSERT": "10",
                    },
                    clear=False,
                ):
                    with self.assertLogs(lambda_function.logger, level="INFO") as captured_logs:
                        result = lambda_function.lambda_handler(
                            event,
                            FakeContext(remaining_time_ms=60000),
                        )

        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "msg-1"}])
        stage_lines = [line for line in captured_logs.output if "ETL stage" in line]
        serialized_index = next(
            index for index, line in enumerate(stage_lines) if '"stage": "sub_batch_serialized"' in line
        )
        failed_index = next(
            index for index, line in enumerate(stage_lines) if '"stage": "sub_batch_failed"' in line
        )
        self.assertLess(serialized_index, failed_index)
        self.assertIn('"outcome": "clickhouse_insert_failed"', stage_lines[failed_index])
        self.assertFalse(any('"stage": "sub_batch_committed"' in line for line in stage_lines))

    def test_lambda_handler_derives_clickhouse_timeout_from_remaining_time(self):
        event = {"Records": [self._message("msg-1")]}

        with mock.patch.object(
            lambda_function,
            "build_arrow_table_from_s3_objects",
            return_value=self._table_with_rows(2),
        ):
            with mock.patch.object(lambda_function, "insert_into_clickhouse") as insert_mock:
                with mock.patch.dict(
                    os.environ,
                    {
                        "CLICKHOUSE_DATABASE": "db",
                        "CLICKHOUSE_TABLE": "tbl",
                        "CLICKHOUSE_TIMEOUT_SECONDS": "30",
                        "LAMBDA_TIMEOUT_SAFETY_MARGIN_MS": "5000",
                        "MIN_REMAINING_TIME_TO_START_INSERT_MS": "1000",
                    },
                    clear=False,
                ):
                    result = lambda_function.lambda_handler(
                        event,
                        FakeContext(remaining_time_ms=12000),
                    )

        self.assertEqual(result["batchItemFailures"], [])
        self.assertEqual(insert_mock.call_args.kwargs["timeout_seconds"], 7.0)

    def test_lambda_handler_skips_s3_test_event(self):
        body = json.dumps(
            {
                "Service": "Amazon S3",
                "Event": "s3:TestEvent",
                "Time": "2025-10-24T18:15:57.331Z",
                "Bucket": "torus-xapi-prod",
            }
        )
        event = {
            "Records": [
                {
                    "messageId": "msg-test",
                    "body": body,
                }
            ]
        }

        with mock.patch.object(lambda_function, "extract_s3_references") as extract_mock:
            result = lambda_function.lambda_handler(event, FakeContext(remaining_time_ms=60000))

        self.assertEqual(result["batchItemFailures"], [])
        extract_mock.assert_not_called()
        self.mock_s3.get_object.assert_not_called()

    def test_diagnostics_request(self):
        event = {"diagnostics": True}

        result = lambda_function.lambda_handler(event, SimpleNamespace())
        self.assertEqual(result["statusCode"], 200)

        payload = json.loads(result["body"])
        self.assertIn("runtime", payload)
        self.assertIn("pyarrow", payload["dependencies"])

    def test_transform_xapi_statement_maps_expected_fields(self):
        event = {
            "id": "d7f92ff8-4bde-4966-b1e3-f1be9a9098fa",
            "actor": {
                "account": {
                    "homePage": "https://proton.oli.cmu.edu",
                    "name": 15474,
                },
                "objectType": "Agent",
            },
            "context": {
                "extensions": {
                    "http://oli.cmu.edu/extensions/activity_attempt_guid": "c282871f-9253-4f73-af64-45794c024a95",
                    "http://oli.cmu.edu/extensions/activity_attempt_number": 1,
                    "http://oli.cmu.edu/extensions/activity_id": 80772,
                    "http://oli.cmu.edu/extensions/activity_revision_id": 388148,
                    "http://oli.cmu.edu/extensions/attached_objectives": [120498],
                    "http://oli.cmu.edu/extensions/hints_requested": [],
                    "http://oli.cmu.edu/extensions/page_attempt_guid": "48e1e3b4-7d3b-435d-92b4-ec10002a507b",
                    "http://oli.cmu.edu/extensions/page_attempt_number": 1,
                    "http://oli.cmu.edu/extensions/page_id": 81181,
                    "http://oli.cmu.edu/extensions/part_attempt_guid": "bb2f47c4-ee8d-4cd3-b29e-93fc7e1004b3",
                    "http://oli.cmu.edu/extensions/part_attempt_number": 1,
                    "http://oli.cmu.edu/extensions/part_id": "132824041",
                    "http://oli.cmu.edu/extensions/project_id": 1719,
                    "http://oli.cmu.edu/extensions/publication_id": 8625,
                    "http://oli.cmu.edu/extensions/section_id": 2161,
                    "http://oli.cmu.edu/extensions/session_id": "70a20ff3-1373-4fe1-af64-59774295d22e",
                }
            },
            "object": {
                "definition": {
                    "name": {"en-US": "Part Attempt"},
                    "type": "http://adlnet.gov/expapi/activities/question",
                },
                "id": "https://proton.oli.cmu.edu/part_attempt/bb2f47c4-ee8d-4cd3-b29e-93fc7e1004b3",
                "objectType": "Activity",
            },
            "result": {
                "completion": True,
                "extensions": {
                    "http://oli.cmu.edu/extensions/feedback": {
                        "content": [
                            {
                                "children": [
                                    {"text": "Incorrect."},
                                ],
                                "id": "8vynyuekul3yctz",
                                "type": "p",
                            }
                        ],
                        "id": "2475577451",
                    }
                },
                "response": {"input": ".138"},
                "score": {"max": 1.0, "min": 0, "raw": 0.0, "scaled": 0.0},
                "success": True,
            },
            "timestamp": "2025-05-21T13:41:06Z",
            "verb": {
                "display": {"en-US": "completed"},
                "id": "http://adlnet.gov/expapi/verbs/completed",
            },
        }

        raw_line = json.dumps(event).encode("utf-8")

        transformed = lambda_function.transform_xapi_statement(
            event,
            raw_bytes=raw_line,
            bucket="bucket",
            key="path/to/file.jsonl",
            etag='"etag"',
            line_number=1,
        )

        self.assertEqual(transformed["event_type"], "part_attempt")
        self.assertEqual(transformed["user_id"], "15474")
        self.assertEqual(transformed["section_id"], 2161)
        self.assertEqual(transformed["project_id"], 1719)
        self.assertEqual(transformed["publication_id"], 8625)
        self.assertEqual(transformed["session_id"], "70a20ff3-1373-4fe1-af64-59774295d22e")
        self.assertEqual(transformed["response"], ".138")
        self.assertEqual(transformed["activity_id"], 80772)
        self.assertEqual(transformed["part_id"], "132824041")
        self.assertTrue(transformed["success"])
        self.assertIsInstance(transformed["attached_objectives"], str)
        self.assertEqual(transformed["source_file"], "s3://bucket/path/to/file.jsonl")
        self.assertEqual(transformed["source_line"], 1)
        self.assertEqual(transformed["source_etag"], "etag")
        self.assertEqual(transformed["event_hash"], hashlib.sha256(raw_line).hexdigest())

    def test_build_insert_query_uses_default_columns(self):
        with mock.patch.dict(
            os.environ,
            {
                "CLICKHOUSE_DATABASE": "db",
                "CLICKHOUSE_TABLE": "raw_events",
            },
            clear=False,
        ):
            query = lambda_function.build_insert_query()

        self.assertTrue(query.startswith("INSERT INTO `db`.`raw_events`"))
        self.assertIn("`user_id`", query)
        self.assertNotIn("`attempt_guid`", query)
        self.assertTrue(query.endswith("FORMAT Parquet"))

    def test_build_insert_query_respects_column_override(self):
        with mock.patch.dict(
            os.environ,
            {
                "CLICKHOUSE_DATABASE": "db",
                "CLICKHOUSE_TABLE": "raw_events",
                "CLICKHOUSE_INSERT_COLUMNS": "user_id,timestamp",
            },
            clear=False,
        ):
            query = lambda_function.build_insert_query()

        self.assertIn("(`user_id`, `timestamp`)", query)
