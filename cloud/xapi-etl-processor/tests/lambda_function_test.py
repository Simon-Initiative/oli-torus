import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest import TestCase, mock

import pytest

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


class LambdaFunctionTests(TestCase):
    def setUp(self):
        patcher = mock.patch.object(lambda_function, "s3_client")
        self.addCleanup(patcher.stop)
        self.mock_s3 = patcher.start()
        self.addCleanup(lambda: os.environ.pop("DRY_RUN", None))

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
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, SimpleNamespace())

        self.assertEqual(result["batchItemFailures"], [])
        insert_mock.assert_called_once()
        args, kwargs = insert_mock.call_args
        self.assertGreater(len(args[0]), 0)  # parquet payload bytes
        self.assertEqual(kwargs, {})

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
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, SimpleNamespace())

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
                },
                clear=False,
            ):
                result = lambda_function.lambda_handler(event, SimpleNamespace())

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
                        },
                        clear=False,
                    ):
                        result = lambda_function.lambda_handler(event, SimpleNamespace())

        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "msg-1"}])
        sqs_mock.send_message.assert_called_once()
        call = sqs_mock.send_message.call_args.kwargs
        self.assertEqual(call["QueueUrl"], "https://example.com/dlq")
        self.assertEqual(json.loads(call["MessageBody"]), json.loads(body))
        self.assertIn("FailureReason", call["MessageAttributes"])

    def test_lambda_handler_sends_clickhouse_failures_to_dlq(self):
        body = json.dumps({"bucket": "bucket", "key": "events/file.jsonl"})
        event = {
            "Records": [
                {"messageId": "msg-1", "body": body},
                {"messageId": "msg-2", "body": body},
            ]
        }

        mock_table = SimpleNamespace(num_rows=3)
        combined_table = SimpleNamespace(num_rows=6)

        with mock.patch.object(lambda_function, "_FAILURE_DLQ_URL", "https://example.com/dlq"):
            with mock.patch.object(lambda_function, "_sqs_client") as sqs_mock:
                with mock.patch.object(lambda_function, "build_arrow_table_from_s3_objects", return_value=mock_table):
                    with mock.patch.object(lambda_function, "concatenate_tables", return_value=combined_table):
                        with mock.patch.object(lambda_function, "table_to_parquet", return_value=b"data"):
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
                                    },
                                    clear=False,
                                ):
                                    result = lambda_function.lambda_handler(event, SimpleNamespace())

        self.assertEqual(
            result["batchItemFailures"],
            [
                {"itemIdentifier": "msg-1"},
                {"itemIdentifier": "msg-2"},
            ],
        )
        self.assertEqual(sqs_mock.send_message.call_count, 2)
        sent_ids = {
            call.kwargs["MessageAttributes"]["OriginalMessageId"]["StringValue"]
            for call in sqs_mock.send_message.mock_calls
        }
        self.assertEqual(sent_ids, {"msg-1", "msg-2"})

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
            result = lambda_function.lambda_handler(event, SimpleNamespace())

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
        self.assertIn("`event_id`", query)
        self.assertNotIn("`attempt_guid`", query)
        self.assertTrue(query.endswith("FORMAT Parquet"))

    def test_build_insert_query_respects_column_override(self):
        with mock.patch.dict(
            os.environ,
            {
                "CLICKHOUSE_DATABASE": "db",
                "CLICKHOUSE_TABLE": "raw_events",
                "CLICKHOUSE_INSERT_COLUMNS": "event_id,timestamp",
            },
            clear=False,
        ):
            query = lambda_function.build_insert_query()

        self.assertIn("(`event_id`, `timestamp`)", query)
