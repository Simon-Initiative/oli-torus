"""
Unit tests for the Lambda function using the unified ClickHouse client
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os

# Add the parent directory to the Python path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lambda_function import lambda_handler


class TestLambdaFunctionUnified(unittest.TestCase):
    """Test suite for the unified Lambda function"""

    def setUp(self):
        """Set up test fixtures"""
        self.sample_event = {
            "Records": [
                {
                    "eventSource": "aws:s3",
                    "s3": {
                        "bucket": {"name": "test-bucket"},
                        "object": {"key": "xapi-events/section_145/2023/09/09/events.jsonl"}
                    }
                }
            ]
        }

        self.sample_context = Mock()
        self.sample_context.aws_request_id = "test-request-id"

    @patch('lambda_function.get_config')
    @patch('lambda_function.ClickHouseClient')
    def test_lambda_handler_success(self, mock_clickhouse_client_class, mock_get_config):
        """Test successful Lambda execution with unified client"""
        # Mock configuration
        mock_get_config.return_value = {
            'clickhouse': {
                'host': 'test-clickhouse',
                'port': 8123,
                'user': 'test_user',
                'password': 'test_pass',
                'database': 'test_db'
            },
            'aws': {
                'access_key_id': 'test_key',
                'secret_access_key': 'test_secret'
            }
        }

        # Mock ClickHouse client instance
        mock_client_instance = Mock()
        mock_client_instance.health_check.return_value = True

        # Create a proper dictionary result instead of a Mock
        bulk_result = {
            'total_events_processed': 1500,
            'video_events_processed': 800,
            'activity_attempt_events_processed': 300,
            'page_attempt_events_processed': 200,
            'page_viewed_events_processed': 150,
            'part_attempt_events_processed': 50
        }
        mock_client_instance.bulk_insert_from_s3.return_value = bulk_result

        # Also mock the S3 integration method
        s3_result = {
            'total_events_processed': 1500,
            'video_events_processed': 800,
            'activity_attempt_events_processed': 300,
            'page_attempt_events_processed': 200,
            'page_viewed_events_processed': 150,
            'part_attempt_events_processed': 50
        }
        mock_client_instance._process_single_s3_file_unified.return_value = s3_result
        mock_clickhouse_client_class.return_value = mock_client_instance

        # Execute Lambda function
        result = lambda_handler(self.sample_event, self.sample_context)

        # Verify response
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['total_events_processed'], 1500)
        self.assertTrue(response_body.get('success', False))

        # Verify ClickHouse client was called correctly
        mock_client_instance.health_check.assert_called_once()
        mock_client_instance._process_single_s3_file_unified.assert_called_once()

    @patch('lambda_function.get_config')
    @patch('lambda_function.ClickHouseClient')
    def test_lambda_handler_health_check_failure(self, mock_clickhouse_client_class, mock_get_config):
        """Test Lambda execution when ClickHouse health check fails"""
        # Mock configuration
        mock_get_config.return_value = {
            'clickhouse': {
                'host': 'test-clickhouse',
                'port': 8123,
                'user': 'test_user',
                'password': 'test_pass',
                'database': 'test_db'
            },
            'aws': {
                'access_key_id': 'test_key',
                'secret_access_key': 'test_secret'
            }
        }

        # Mock ClickHouse client instance with failed health check
        mock_client_instance = Mock()
        mock_client_instance.health_check.return_value = False

        mock_client_instance._process_single_s3_file_unified.side_effect = Exception("ClickHouse health check failed")
        mock_clickhouse_client_class.return_value = mock_client_instance

        # Execute Lambda function
        result = lambda_handler(self.sample_event, self.sample_context)

        # Verify error response
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('ClickHouse health check failed', response_body['error'])

    @patch('lambda_function.get_config')
    @patch('lambda_function.ClickHouseClient')
    def test_lambda_handler_processing_error(self, mock_clickhouse_client_class, mock_get_config):
        """Test Lambda execution when processing fails"""
        # Mock configuration
        mock_get_config.return_value = {
            'clickhouse': {
                'host': 'test-clickhouse',
                'port': 8123,
                'user': 'test_user',
                'password': 'test_pass',
                'database': 'test_db'
            },
            'aws': {
                'access_key_id': 'test_key',
                'secret_access_key': 'test_secret'
            }
        }

        # Mock ClickHouse client instance that throws an error during processing
        mock_client_instance = Mock()
        mock_client_instance.health_check.return_value = True
        mock_client_instance.bulk_insert_from_s3.side_effect = Exception("Processing failed")
        mock_client_instance._process_single_s3_file_unified.side_effect = Exception("Processing failed")
        mock_clickhouse_client_class.return_value = mock_client_instance

        # Execute Lambda function
        result = lambda_handler(self.sample_event, self.sample_context)

        # Verify error response
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('Processing failed', response_body['error'])

    def test_lambda_handler_invalid_event(self):
        """Test Lambda execution with invalid event structure"""
        invalid_event = {"invalid": "structure"}

        # Execute Lambda function
        result = lambda_handler(invalid_event, self.sample_context)

        # Verify error response
        self.assertEqual(result['statusCode'], 400)
        response_body = json.loads(result['body'])
        self.assertIn('Invalid S3 event format', response_body['error'])

    @patch('lambda_function.get_config')
    @patch('lambda_function.ClickHouseClient')
    def test_lambda_handler_multiple_files(self, mock_clickhouse_client_class, mock_get_config):
        """Test Lambda execution with multiple S3 files"""
        # Create event with multiple S3 records
        multi_file_event = {
            "Records": [
                {
                    "eventSource": "aws:s3",
                    "s3": {
                        "bucket": {"name": "test-bucket"},
                        "object": {"key": "xapi-events/section_145/2023/09/09/events1.jsonl"}
                    }
                },
                {
                    "eventSource": "aws:s3",
                    "s3": {
                        "bucket": {"name": "test-bucket"},
                        "object": {"key": "xapi-events/section_145/2023/09/09/events2.jsonl"}
                    }
                }
            ]
        }

        # Mock configuration
        mock_get_config.return_value = {
            'clickhouse': {
                'host': 'test-clickhouse',
                'port': 8123,
                'user': 'test_user',
                'password': 'test_pass',
                'database': 'test_db'
            },
            'aws': {
                'access_key_id': 'test_key',
                'secret_access_key': 'test_secret'
            }
        }

        # Mock ClickHouse client instance
        mock_client_instance = Mock()
        mock_client_instance.health_check.return_value = True

        # Create a proper dictionary result
        bulk_result = {
            'total_events_processed': 3000,
            'video_events_processed': 1600,
            'activity_attempt_events_processed': 600,
            'page_attempt_events_processed': 400,
            'page_viewed_events_processed': 300,
            'part_attempt_events_processed': 100
        }
        mock_client_instance.bulk_insert_from_s3.return_value = bulk_result

        # Also mock the S3 integration method
        s3_result = {
            'total_events_processed': 1500,
            'video_events_processed': 800,
            'activity_attempt_events_processed': 300,
            'page_attempt_events_processed': 200,
            'page_viewed_events_processed': 150,
            'part_attempt_events_processed': 50
        }
        mock_client_instance._process_single_s3_file_unified.return_value = s3_result
        mock_clickhouse_client_class.return_value = mock_client_instance

        # Execute Lambda function
        result = lambda_handler(multi_file_event, self.sample_context)

        # Verify response (only first file should be processed)
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        # Should only process the first file (1500 events)
        self.assertEqual(response_body['total_events_processed'], 1500)

        # Verify that S3 integration method was called for the first file
        mock_client_instance._process_single_s3_file_unified.assert_called_once()


if __name__ == '__main__':
    unittest.main(verbosity=2)
