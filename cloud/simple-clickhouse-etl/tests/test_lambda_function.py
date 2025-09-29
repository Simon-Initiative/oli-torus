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

    def test_diagnostics_request(self):
        event = {"diagnostics": True}

        result = lambda_function.lambda_handler(event, SimpleNamespace())
        self.assertEqual(result["statusCode"], 200)

        payload = json.loads(result["body"])
        self.assertIn("runtime", payload)
        self.assertIn("pyarrow", payload["dependencies"])
