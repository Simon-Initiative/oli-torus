"""
Integration tests for the complete unified XAPI ETL system
Tests end-to-end functionality with mocked AWS services
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os
from datetime import datetime, timezone

# Add the parent directory to the Python path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from clickhouse_client import ClickHouseClient
from lambda_function import lambda_handler


class TestUnifiedSystemIntegration(unittest.TestCase):
    """Integration tests for the unified XAPI ETL system"""

    def setUp(self):
        """Set up test fixtures"""
        self.sample_events = [
            {
                "id": "test-event-1",
                "actor": {"mbox": "mailto:student@example.com"},
                "verb": {"id": "http://adlnet.gov/expapi/verbs/experienced"},
                "object": {
                    "id": "http://example.com/video/12345",
                    "definition": {
                        "type": "https://w3id.org/xapi/video/activity-types/video",
                        "extensions": {
                            "http://oli.cmu.edu/extensions/video_length": 180
                        }
                    }
                },
                "context": {
                    "extensions": {
                        "http://oli.cmu.edu/extensions/section_id": 145,
                        "http://oli.cmu.edu/extensions/project_id": 1,
                        "http://oli.cmu.edu/extensions/publication_id": 1,
                        "http://oli.cmu.edu/extensions/session_id": "session-123"
                    }
                },
                "result": {
                    "extensions": {
                        "http://oli.cmu.edu/extensions/video_time": 45
                    }
                },
                "timestamp": "2023-09-09T12:00:00Z"
            }
        ]

    def test_end_to_end_event_processing(self):
        """Test complete event processing pipeline from raw events to ClickHouse insertion"""
        client = ClickHouseClient()

        # Mock the ClickHouse connection
        with patch.object(client, '_execute_query') as mock_execute:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.text = "1\n"  # Simulate 1 inserted row
            mock_execute.return_value = mock_response

            # Transform events
            transformed_events = []
            for event in self.sample_events:
                transformed = client._transform_raw_event(event)
                transformed_events.append(transformed)

            # Verify the transformation worked
            self.assertEqual(len(transformed_events), 1)
            self.assertEqual(transformed_events[0]['event_type'], 'video')

    @patch('lambda_function.get_config')
    @patch('lambda_function.ClickHouseClient')
    def test_lambda_s3_integration_unified(self, mock_clickhouse_client_class, mock_get_config):
        """Test Lambda function with S3 integration using unified table approach"""
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

        # Mock ClickHouse client that simulates successful processing
        mock_client_instance = Mock()
        mock_client_instance.health_check.return_value = True

        # Create a proper dictionary result
        s3_result = {
            'total_events_processed': 3,
            'video_events_processed': 1,
            'activity_attempt_events_processed': 1,
            'page_attempt_events_processed': 0,
            'page_viewed_events_processed': 1,
            'part_attempt_events_processed': 0
        }
        mock_client_instance._process_single_s3_file_unified.return_value = s3_result
        mock_clickhouse_client_class.return_value = mock_client_instance

        # Create test event
        lambda_event = {
            "Records": [
                {
                    "eventSource": "aws:s3",
                    "s3": {
                        "bucket": {"name": "test-xapi-bucket"},
                        "object": {"key": "xapi-events/section_145/2023/09/09/sample-events.jsonl"}
                    }
                }
            ]
        }

        context = Mock()
        context.aws_request_id = "test-request-id"

        # Execute Lambda function
        result = lambda_handler(lambda_event, context)

        # Verify successful processing
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['total_events_processed'], 3)

        # Verify unified S3 processing was called
        mock_client_instance._process_single_s3_file_unified.assert_called_once()

    def test_unified_bulk_s3_processing_simulation(self):
        """Test S3 bulk processing with unified table approach (simulated)"""
        client = ClickHouseClient()

        # Mock the S3 bulk processing and AWS configuration
        with patch.object(client, '_execute_query') as mock_execute, \
             patch.object(client, '_build_s3_function_call') as mock_s3_call:

            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.text = "video\t1\nactivity_attempt\t2\n"  # Simulate event counts by type
            mock_execute.return_value = mock_response

            # Mock S3 function call to avoid AWS credential issues
            mock_s3_call.return_value = "s3Cluster('default', 's3://test-bucket/sample-events.jsonl', 'JSONEachRow')"

            # Simulate bulk S3 processing
            s3_paths = ["s3://test-bucket/sample-events.jsonl"]
            result = client.bulk_insert_from_s3(s3_paths)

            # Verify processing
            self.assertEqual(result['total_events_processed'], 3)
            self.assertEqual(result['video_events_processed'], 1)
            self.assertEqual(result['activity_attempt_events_processed'], 2)
            mock_execute.assert_called()

    def test_unified_event_type_mapping(self):
        """Test that all event types are correctly mapped in the unified system"""
        client = ClickHouseClient()

        # Test video event type determination
        video_event = {
            "verb": {"id": "http://adlnet.gov/expapi/verbs/experienced"},
            "object": {
                "definition": {
                    "type": "https://w3id.org/xapi/video/activity-types/video"
                }
            }
        }
        verb_id = video_event["verb"]["id"]
        object_type = video_event["object"]["definition"]["type"]
        self.assertEqual(client._determine_event_type(verb_id, object_type), 'video')

        # Test activity attempt event type determination
        activity_event = {
            "verb": {"id": "http://adlnet.gov/expapi/verbs/completed"},
            "object": {
                "definition": {
                    "type": "http://oli.cmu.edu/extensions/activity_attempt"
                }
            }
        }
        verb_id = activity_event["verb"]["id"]
        object_type = activity_event["object"]["definition"]["type"]
        self.assertEqual(client._determine_event_type(verb_id, object_type), 'activity_attempt')

    def test_unified_performance_characteristics(self):
        """Test performance characteristics of the unified approach"""
        client = ClickHouseClient()

        # Generate multiple events for performance testing
        test_events = []
        for i in range(100):
            event = {
                "id": f"test-event-{i}",
                "actor": {"mbox": f"mailto:student{i}@example.com"},
                "verb": {"id": "http://adlnet.gov/expapi/verbs/experienced"},
                "object": {
                    "id": f"http://example.com/content/{i}",
                    "definition": {"type": "http://adlnet.gov/expapi/activities/lesson"}
                },
                "timestamp": "2023-09-09T12:00:00Z"
            }
            test_events.append(event)

        # Transform all events
        transformed_events = []
        for event in test_events:
            transformed = client._transform_raw_event(event)
            transformed_events.append(transformed)

        # Verify all events were transformed
        self.assertEqual(len(transformed_events), 100)

        # Verify all have the same base structure
        for transformed in transformed_events:
            self.assertIn('event_id', transformed)
            self.assertIn('event_type', transformed)
            self.assertIn('timestamp', transformed)


if __name__ == '__main__':
    unittest.main(verbosity=2)
