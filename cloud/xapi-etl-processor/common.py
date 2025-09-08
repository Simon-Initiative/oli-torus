"""
Common utilities and configurations for XAPI ETL pipeline
"""
import json
import logging
import os
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_config() -> Dict[str, Any]:
    """Get configuration from environment variables"""
    return {
        'clickhouse': {
            'scheme': os.getenv('CLICKHOUSE_SCHEME', 'http'),
            'host': os.getenv('CLICKHOUSE_HOST', 'localhost'),
            'port': int(os.getenv('CLICKHOUSE_PORT', '8123')),
            'user': os.getenv('CLICKHOUSE_USER', 'default'),
            'password': os.getenv('CLICKHOUSE_PASSWORD', 'clickhouse'),
            'database': os.getenv('CLICKHOUSE_DATABASE', 'oli_analytics_dev')
        },
        'environment': os.getenv('ENVIRONMENT', 'dev'),
        'aws': {
            'region': os.getenv('AWS_REGION', 'us-east-1'),
            'access_key_id': os.getenv('AWS_ACCESS_KEY_ID'),
            'secret_access_key': os.getenv('AWS_SECRET_ACCESS_KEY')
        }
    }

def parse_s3_event(event: Dict[str, Any]) -> Optional[Dict[str, str]]:
    """Parse S3 event to extract bucket and key information"""
    try:
        # Handle direct S3 event notification
        if 'Records' in event:
            record = event['Records'][0]
            if record.get('eventSource') == 'aws:s3':
                s3_info = record['s3']
                return {
                    'bucket': s3_info['bucket']['name'],
                    'key': s3_info['object']['key']
                }

        # Handle EventBridge S3 event
        if 'source' in event and event['source'] == 'aws.s3':
            detail = event.get('detail', {})
            if 'bucket' in detail and 'object' in detail:
                return {
                    'bucket': detail['bucket']['name'],
                    'key': detail['object']['key']
                }

        # Handle manual invocation with bucket/key
        if 'bucket' in event and 'key' in event:
            return {
                'bucket': event['bucket'],
                'key': event['key']
            }

        logger.warning(f"Could not parse S3 information from event: {json.dumps(event)}")
        return None

    except Exception as e:
        logger.error(f"Error parsing S3 event: {str(e)}")
        return None

def is_video_event(event_data: Dict[str, Any]) -> bool:
    """Check if the xAPI event is a video-related event"""
    verb_id = event_data.get('verb', {}).get('id', '')

    video_verbs = [
        'https://w3id.org/xapi/video/verbs/played',
        'https://w3id.org/xapi/video/verbs/paused',
        'https://w3id.org/xapi/video/verbs/seeked',
        'https://w3id.org/xapi/video/verbs/completed',
        'http://adlnet.gov/expapi/verbs/experienced'  # Legacy
    ]

    return verb_id in video_verbs

def is_activity_attempt_event(event_data: Dict[str, Any]) -> bool:
    """Check if the xAPI event is an activity attempt event"""
    verb_id = event_data.get('verb', {}).get('id', '')
    object_type = safe_get_nested(event_data, 'object.definition.type', '')

    return (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://oli.cmu.edu/extensions/activity_attempt')

def is_page_attempt_event(event_data: Dict[str, Any]) -> bool:
    """Check if the xAPI event is a page attempt event"""
    verb_id = event_data.get('verb', {}).get('id', '')
    object_type = safe_get_nested(event_data, 'object.definition.type', '')

    return (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://oli.cmu.edu/extensions/page_attempt')

def is_page_viewed_event(event_data: Dict[str, Any]) -> bool:
    """Check if the xAPI event is a page viewed event"""
    verb_id = event_data.get('verb', {}).get('id', '')
    object_type = safe_get_nested(event_data, 'object.definition.type', '')

    return (verb_id == 'http://id.tincanapi.com/verb/viewed' and
            object_type == 'http://oli.cmu.edu/extensions/types/page')

def is_part_attempt_event(event_data: Dict[str, Any]) -> bool:
    """Check if the xAPI event is a part attempt event"""
    verb_id = event_data.get('verb', {}).get('id', '')
    object_type = safe_get_nested(event_data, 'object.definition.type', '')

    return (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://adlnet.gov/expapi/activities/question')

def format_clickhouse_timestamp(timestamp_str: str) -> str:
    """Convert ISO8601 timestamp to ClickHouse format"""
    # Remove 'Z' suffix if present
    return timestamp_str.replace('Z', '') if timestamp_str else ''

def extract_section_id_from_s3_key(s3_key: str) -> Optional[str]:
    """Extract section ID from S3 key path"""
    # Expected format: section/{section_id}/video/timestamp_bundle_id.jsonl
    try:
        parts = s3_key.split('/')
        if len(parts) >= 2 and parts[0] == 'section':
            return parts[1]
    except Exception as e:
        logger.warning(f"Could not extract section_id from S3 key {s3_key}: {str(e)}")
    return None

def safe_get_nested(data: Dict[str, Any], path: str, default=None):
    """Safely get nested dictionary value using dot notation"""
    try:
        keys = path.split('.')
        current = data
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return default
        return current
    except Exception:
        return default

def format_sql_value(value) -> str:
    """Format a value for SQL insertion"""
    if value is None:
        return 'NULL'
    elif isinstance(value, str):
        # Use single quotes with proper escaping for ClickHouse
        # Escape backslashes first, then single quotes
        escaped = value.replace('\\', '\\\\').replace("'", "''")
        return f"'{escaped}'"
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, bool):
        return str(value).lower()
    else:
        # For other types, convert to string and escape
        str_value = str(value).replace('\\', '\\\\').replace("'", "''")
        return f"'{str_value}'"
