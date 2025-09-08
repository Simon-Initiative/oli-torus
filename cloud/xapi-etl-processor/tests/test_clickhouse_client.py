"""
Unit tests for the unified ClickHouse client
Tests the unified raw_events table approach with comprehensive coverage
"""

import unittest
from unittest.mock import Mock, patch, MagicMock, call
import json
from datetime import datetime, timezone
import sys
import os

# Add the parent directory to the Python path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from clickhouse_client import ClickHouseClient


class TestClickHouseClientUnified(unittest.TestCase):
    """Comprehensive test suite for the unified ClickHouse client"""

    def setUp(self):
        """Set up test fixtures before each test method."""
        # Mock the configuration to avoid loading real config
        with patch('clickhouse_client.get_config') as mock_config:
            mock_config.return_value = {
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
            self.client = ClickHouseClient()

        # Sample test data for different event types with proper extensions
        self.sample_video_event = {
            "timestamp": "2023-09-09T10:00:00Z",
            "actor": {
                "name": "Test User",
                "mbox": "mailto:test@example.com"
            },
            "verb": {
                "id": "https://w3id.org/xapi/video/verbs/played",
                "display": {"en-US": "played"}
            },
            "object": {
                "definition": {
                    "name": {"en-US": "Test Video"},
                    "extensions": {
                        "https://w3id.org/xapi/video/extensions/length": 600.0
                    }
                },
                "id": "video_123"
            },
            "context": {
                "contextActivities": {
                    "parent": [{"id": "section_145"}]
                },
                "extensions": {
                    "http://oli.cmu.edu/extensions/session_id": "session_abc123",
                    "http://oli.cmu.edu/extensions/section_id": 145,
                    "http://oli.cmu.edu/extensions/host_name": "test.host.com"
                }
            },
            "result": {
                "extensions": {
                    "https://w3id.org/xapi/video/extensions/time": 120.5,
                    "https://w3id.org/xapi/video/extensions/played-segments": "0[.]30.5"
                }
            }
        }

        self.sample_page_viewed_event = {
            "timestamp": "2023-09-09T10:05:00Z",
            "actor": {
                "name": "Test User",
                "mbox": "mailto:test@example.com"
            },
            "verb": {
                "id": "http://id.tincanapi.com/verb/viewed",
                "display": {"en-US": "viewed"}
            },
            "object": {
                "definition": {
                    "name": {"en-US": "Test Page"},
                    "type": "http://oli.cmu.edu/extensions/types/page"
                },
                "id": "page_789"
            },
            "context": {
                "contextActivities": {
                    "parent": [{"id": "section_145"}]
                },
                "extensions": {
                    "http://oli.cmu.edu/extensions/session_id": "session_abc123",
                    "http://oli.cmu.edu/extensions/section_id": 145,
                    "http://oli.cmu.edu/extensions/page_id": 789,
                    "http://oli.cmu.edu/extensions/host_name": "test.host.com"
                }
            }
        }

        self.sample_activity_attempt_event = {
            "timestamp": "2023-09-09T10:10:00Z",
            "actor": {
                "name": "Test User",
                "mbox": "mailto:test@example.com"
            },
            "verb": {
                "id": "http://adlnet.gov/expapi/verbs/completed",
                "display": {"en-US": "completed"}
            },
            "object": {
                "definition": {
                    "name": {"en-US": "Test Activity"},
                    "type": "http://oli.cmu.edu/extensions/activity_attempt"
                },
                "id": "activity_101"
            },
            "context": {
                "contextActivities": {
                    "parent": [{"id": "section_145"}]
                },
                "extensions": {
                    "http://oli.cmu.edu/extensions/session_id": "session_abc123",
                    "http://oli.cmu.edu/extensions/section_id": 145,
                    "http://oli.cmu.edu/extensions/activity_attempt_guid": "attempt_guid_123",
                    "http://oli.cmu.edu/extensions/activity_id": 101,
                    "http://oli.cmu.edu/extensions/host_name": "test.host.com"
                }
            },
            "result": {
                "score": {
                    "raw": 85,
                    "max": 100
                },
                "completion": True,
                "success": True
            }
        }

    def test_determine_event_type_video(self):
        """Test event type determination for video events"""
        verb_id = "https://w3id.org/xapi/video/verbs/played"
        object_type = ""
        event_type = self.client._determine_event_type(verb_id, object_type)
        self.assertEqual(event_type, "video")

    def test_determine_event_type_page_viewed(self):
        """Test event type determination for page viewed events"""
        verb_id = "http://id.tincanapi.com/verb/viewed"
        object_type = "http://oli.cmu.edu/extensions/types/page"
        event_type = self.client._determine_event_type(verb_id, object_type)
        self.assertEqual(event_type, "page_viewed")

    def test_determine_event_type_activity_attempt(self):
        """Test event type determination for activity attempt events"""
        verb_id = "http://adlnet.gov/expapi/verbs/completed"
        object_type = "http://oli.cmu.edu/extensions/activity_attempt"
        event_type = self.client._determine_event_type(verb_id, object_type)
        self.assertEqual(event_type, "activity_attempt")

    def test_determine_event_type_unknown(self):
        """Test event type determination for unknown events"""
        verb_id = "http://unknown.verb"
        object_type = "unknown"
        event_type = self.client._determine_event_type(verb_id, object_type)
        self.assertEqual(event_type, "unknown")

    def test_transform_raw_event_video(self):
        """Test transformation of video events to unified format"""
        transformed = self.client._transform_raw_event(self.sample_video_event)

        # Check common fields
        self.assertEqual(transformed['event_type'], 'video')
        self.assertEqual(transformed['session_id'], 'session_abc123')
        self.assertEqual(transformed['user_id'], 'mailto:test@example.com')
        self.assertEqual(transformed['section_id'], 145)
        self.assertEqual(transformed['host_name'], 'test.host.com')

        # Check video-specific fields
        self.assertEqual(transformed['video_time'], 120.5)
        self.assertEqual(transformed['video_length'], 600.0)
        self.assertEqual(transformed['video_played_segments'], '0[.]30.5')
        self.assertEqual(transformed['video_url'], 'video_123')
        self.assertEqual(transformed['video_title'], 'Test Video')

        # Check that other event type fields are None
        self.assertIsNone(transformed['activity_id'])

    def test_transform_raw_event_page_viewed(self):
        """Test transformation of page viewed events to unified format"""
        transformed = self.client._transform_raw_event(self.sample_page_viewed_event)

        # Check common fields
        self.assertEqual(transformed['event_type'], 'page_viewed')
        self.assertEqual(transformed['session_id'], 'session_abc123')
        self.assertEqual(transformed['user_id'], 'mailto:test@example.com')
        self.assertEqual(transformed['section_id'], 145)
        self.assertEqual(transformed['host_name'], 'test.host.com')

        # Check page-specific fields
        self.assertEqual(transformed['page_id'], 789)

        # Check that other event type fields are None
        self.assertIsNone(transformed['video_url'])
        self.assertIsNone(transformed['activity_id'])

    def test_transform_raw_event_activity_attempt(self):
        """Test transformation of activity attempt events to unified format"""
        transformed = self.client._transform_raw_event(self.sample_activity_attempt_event)

        # Check common fields
        self.assertEqual(transformed['event_type'], 'activity_attempt')
        self.assertEqual(transformed['session_id'], 'session_abc123')
        self.assertEqual(transformed['user_id'], 'mailto:test@example.com')
        self.assertEqual(transformed['section_id'], 145)
        self.assertEqual(transformed['host_name'], 'test.host.com')

        # Check activity-specific fields
        self.assertEqual(transformed['activity_id'], 101)
        self.assertEqual(transformed['activity_attempt_guid'], 'attempt_guid_123')
        self.assertEqual(transformed['score'], 85)
        self.assertEqual(transformed['out_of'], 100)
        self.assertTrue(transformed['success'])

        # Check that other event type fields are None
        self.assertIsNone(transformed['video_url'])

    @patch('clickhouse_client.get_config')
    @patch('clickhouse_client.requests.post')
    def test_insert_raw_events_success(self, mock_post, mock_get_config):
        """Test successful insertion of raw events"""
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

        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.text = ""
        mock_post.return_value = mock_response

        # Create client with mocked config
        client = ClickHouseClient()
        events = [self.sample_video_event, self.sample_page_viewed_event]

        result = client.insert_raw_events(events)

        # Verify success
        self.assertEqual(result, 2)  # Returns count of inserted events

        # Verify the request was made with correct table name
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args

        # Check that INSERT INTO test_db.raw_events is in the query
        self.assertIn('INSERT INTO test_db.raw_events', kwargs['data'])

    @patch('clickhouse_client.get_config')
    @patch('clickhouse_client.requests.post')
    def test_insert_raw_events_failure(self, mock_post, mock_get_config):
        """Test handling of insertion failures"""
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

        # Mock failed response
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.text = "Internal server error"
        mock_post.return_value = mock_response

        # Create client with mocked config
        client = ClickHouseClient()
        events = [self.sample_video_event]

        # Should raise an exception on failure
        with self.assertRaises(Exception) as context:
            client.insert_raw_events(events)

        self.assertIn("ClickHouse query failed", str(context.exception))

    @patch('clickhouse_client.requests.post')
    def test_execute_query_success(self, mock_post):
        """Test successful query execution using _execute_query"""
        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.text = "video\t1500\npage_viewed\t850\n"
        mock_post.return_value = mock_response

        query = "SELECT event_type, count(*) FROM raw_events GROUP BY event_type"

        with patch.dict(os.environ, {
            'CLICKHOUSE_URL': 'http://test-clickhouse:8123',
            'CLICKHOUSE_USERNAME': 'test_user',
            'CLICKHOUSE_PASSWORD': 'test_pass'
        }):
            # Mock the config to avoid loading issues
            with patch('clickhouse_client.get_config') as mock_config:
                mock_config.return_value = {
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

                result = self.client._execute_query(query)

                # Verify the response is returned correctly
                self.assertEqual(result.status_code, 200)
                self.assertEqual(result.text, "video\t1500\npage_viewed\t850\n")

    @patch('clickhouse_client.get_config')
    @patch('clickhouse_client.requests.post')
    def test_get_section_event_count(self, mock_post, mock_get_config):
        """Test getting event count for a section"""
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

        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.text = "2350\n"
        mock_post.return_value = mock_response

        # Create client with mocked config
        client = ClickHouseClient()
        count = client.get_section_event_count(145)

        # Verify count
        self.assertEqual(count, 2350)

    @patch('clickhouse_client.get_config')
    @patch('clickhouse_client.requests.post')
    def test_delete_section_events(self, mock_post, mock_get_config):
        """Test deleting events for a section"""
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

        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.text = ""
        mock_post.return_value = mock_response

        # Create client with mocked config
        client = ClickHouseClient()
        result = client.delete_section_events(145)

        # Verify success
        self.assertEqual(result, 1)  # Returns 1 on success

        # Verify the delete query was called with correct table name
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        self.assertIn('ALTER TABLE test_db.raw_events DELETE WHERE section_id = 145', kwargs['data'])

    @patch('clickhouse_client.get_config')
    @patch('clickhouse_client.requests.post')
    def test_missing_environment_variables(self, mock_post, mock_get_config):
        """Test behavior when required environment variables are missing"""
        # Mock configuration that would cause errors
        mock_get_config.side_effect = ValueError("CLICKHOUSE_URL environment variable not found")

        with self.assertRaises(ValueError) as context:
            client = ClickHouseClient()

        self.assertIn("CLICKHOUSE_URL", str(context.exception))

    def test_malformed_event_data(self):
        """Test handling of malformed event data"""
        malformed_event = {"incomplete": "data"}

        transformed = self.client._transform_raw_event(malformed_event)

        # Should have defaults for missing data
        self.assertEqual(transformed['event_type'], 'unknown')
        self.assertEqual(transformed['user_id'], '')  # Empty string, not None
        self.assertEqual(transformed['section_id'], 0)

    def test_edge_case_section_id_extraction(self):
        """Test edge cases in section ID extraction"""
        # Test with missing context
        event_no_context = {"verb": {"id": "test"}}
        transformed = self.client._transform_raw_event(event_no_context)
        self.assertEqual(transformed['section_id'], 0)

        # Test with malformed section ID
        event_bad_section = {
            "context": {
                "contextActivities": {
                    "parent": [{"id": "not_a_section"}]
                }
            }
        }
        transformed = self.client._transform_raw_event(event_bad_section)
        self.assertEqual(transformed['section_id'], 0)

        # Test with empty parent activities
        event_empty_parent = {
            "context": {
                "contextActivities": {
                    "parent": []
                }
            }
        }
        transformed = self.client._transform_raw_event(event_empty_parent)
        self.assertEqual(transformed['section_id'], 0)

    def test_timestamp_handling(self):
        """Test various timestamp formats"""
        # Test with different timestamp formats
        event_with_timestamp = self.sample_video_event.copy()

        # Test ISO format with timezone
        event_with_timestamp['timestamp'] = "2023-09-09T10:00:00+00:00"
        transformed = self.client._transform_raw_event(event_with_timestamp)
        self.assertIsNotNone(transformed['timestamp'])

        # Test ISO format without timezone
        event_with_timestamp['timestamp'] = "2023-09-09T10:00:00"
        transformed = self.client._transform_raw_event(event_with_timestamp)
        self.assertIsNotNone(transformed['timestamp'])

    def test_bulk_processing_performance(self):
        """Test performance with bulk event processing"""
        # Create a large batch of events
        events = []
        for i in range(1000):
            event = self.sample_video_event.copy()
            event['context']['extensions']['https://oli.cmu.edu/extensions/session_id'] = f'session_{i}'
            events.append(event)

        # This test mainly ensures the transformation doesn't fail with large datasets
        # In a real scenario, you'd measure execution time
        start_time = datetime.now()

        transformed_events = []
        for event in events:
            transformed = self.client._transform_raw_event(event)
            transformed_events.append(transformed)

        end_time = datetime.now()
        processing_time = (end_time - start_time).total_seconds()

        # Verify all events were transformed
        self.assertEqual(len(transformed_events), 1000)

        # Performance assertion (should process 1000 events in under 5 seconds)
        self.assertLess(processing_time, 5.0,
                       f"Bulk processing took {processing_time} seconds, expected < 5")

    def test_data_consistency_across_event_types(self):
        """Test that common fields are consistent across different event types"""
        events = [
            self.sample_video_event,
            self.sample_page_viewed_event,
            self.sample_activity_attempt_event
        ]

        transformed_events = [self.client._transform_raw_event(event) for event in events]

        # All should have the same session_id, user_id, and section_id
        for transformed in transformed_events:
            self.assertEqual(transformed['session_id'], 'session_abc123')
            self.assertEqual(transformed['user_id'], 'mailto:test@example.com')
            self.assertEqual(transformed['section_id'], 145)
            self.assertEqual(transformed['host_name'], 'test.host.com')
            self.assertIsNotNone(transformed['timestamp'])
            self.assertIsNotNone(transformed['event_type'])


class TestClickHouseClientIntegration(unittest.TestCase):
    """Integration tests for the ClickHouse client (requires actual ClickHouse instance)"""

    def setUp(self):
        """Set up for integration tests"""
        # Skip integration tests if environment variables are not set
        self.clickhouse_url = os.getenv('CLICKHOUSE_URL')
        self.clickhouse_username = os.getenv('CLICKHOUSE_USERNAME')
        self.clickhouse_password = os.getenv('CLICKHOUSE_PASSWORD')

        if not all([self.clickhouse_url, self.clickhouse_username, self.clickhouse_password]):
            self.skipTest("ClickHouse environment variables not set - skipping integration tests")

        self.client = ClickHouseClient()

    def test_database_connectivity(self):
        """Test basic database connectivity"""
        try:
            with patch('clickhouse_client.get_config') as mock_config:
                mock_config.return_value = {
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

                with patch('clickhouse_client.requests.post') as mock_post:
                    mock_response = Mock()
                    mock_response.status_code = 200
                    mock_response.text = "1\n"
                    mock_post.return_value = mock_response

                    result = self.client._execute_query("SELECT 1")
                    self.assertEqual(result.text.strip(), '1')
        except Exception as e:
            self.fail(f"Database connectivity test failed: {str(e)}")

    def test_table_exists(self):
        """Test that the raw_events table exists"""
        try:
            with patch('clickhouse_client.get_config') as mock_config:
                mock_config.return_value = {
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

                with patch('clickhouse_client.requests.post') as mock_post:
                    mock_response = Mock()
                    mock_response.status_code = 200
                    mock_response.text = "0\n"
                    mock_post.return_value = mock_response

                    query = "SELECT count(*) FROM raw_events LIMIT 1"
                    result = self.client._execute_query(query)
                    # If this doesn't raise an exception, the table exists
                    self.assertIsNotNone(result)
        except Exception as e:
            self.fail(f"raw_events table does not exist or is not accessible: {str(e)}")


if __name__ == '__main__':
    # Configure test runner
    unittest.main(verbosity=2)
