"""
Simplified ClickHouse client for XAPI ETL pipeline using unified raw_events table
"""
import json
import logging
import requests
import uuid
from typing import List, Dict, Any, Optional
from datetime import datetime
from common import get_config, format_clickhouse_timestamp, safe_get_nested, format_sql_value

logger = logging.getLogger(__name__)

def safe_int_convert(value, default=0):
    """Safely convert a value to integer, handling lists and other edge cases"""
    if value is None:
        return default

    # If it's a list, take the first element
    if isinstance(value, list):
        if len(value) > 0:
            value = value[0]
        else:
            return default

    # Try to convert to int
    try:
        return int(value)
    except (ValueError, TypeError):
        logger.warning(f"Could not convert value {value} to int, using default {default}")
        return default

def safe_float_convert(value, default=None):
    """Safely convert a value to float, handling lists and other edge cases"""
    if value is None:
        return default

    # If it's a list, take the first element
    if isinstance(value, list):
        if len(value) > 0:
            value = value[0]
        else:
            return default

    # Try to convert to float
    try:
        return float(value)
    except (ValueError, TypeError):
        logger.warning(f"Could not convert value {value} to float, using default {default}")
        return default

class ClickHouseClient:
    def __init__(self):
        config = get_config()
        self.config = config['clickhouse']
        self.aws_config = config.get('aws', {})
        self.base_url = f"http://{self.config['host']}:{self.config['port']}"
        self.database = self.config['database']

    def _execute_query(self, query: str) -> requests.Response:
        """Execute a query against ClickHouse"""
        headers = {
            'Content-Type': 'text/plain',
            'X-ClickHouse-User': self.config['user'],
            'X-ClickHouse-Key': self.config['password']
        }

        response = requests.post(self.base_url, data=query, headers=headers)

        if response.status_code != 200:
            logger.error(f"ClickHouse query failed with status {response.status_code}: {response.text}")
            raise Exception(f"ClickHouse query failed: {response.text}")

        return response

    def health_check(self) -> bool:
        """Check if ClickHouse is accessible"""
        try:
            response = self._execute_query("SELECT 1")
            return response.status_code == 200
        except Exception as e:
            logger.error(f"ClickHouse health check failed: {str(e)}")
            return False

    def get_raw_events_table(self) -> str:
        """Get the fully qualified raw events table name"""
        return f"{self.database}.raw_events"

    def _build_s3_function_call(self, s3_path: str) -> str:
        """Build S3 function call with AWS credentials"""
        access_key = self.aws_config.get('access_key_id')
        secret_key = self.aws_config.get('secret_access_key')

        if not access_key or not secret_key:
            raise Exception(
                "AWS credentials not found in configuration. "
                "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set in your environment. "
                "Copy example.env to .env and update with your credentials, then source the file."
            )

        # Convert s3:// URI to HTTPS URL format that ClickHouse expects
        if s3_path.startswith('s3://'):
            # Parse s3://bucket/key to https://s3.amazonaws.com/bucket/key
            s3_path_parts = s3_path[5:]  # Remove 's3://' prefix
            if '/' in s3_path_parts:
                bucket, key = s3_path_parts.split('/', 1)
                https_url = f"https://s3.amazonaws.com/{bucket}/{key}"
            else:
                # Just bucket name, no key
                https_url = f"https://s3.amazonaws.com/{s3_path_parts}/"
        else:
            # Assume it's already in HTTPS format
            https_url = s3_path

        # Use single quotes for ClickHouse string literals and escape any single quotes in the values
        escaped_url = https_url.replace("'", "''")
        escaped_access_key = access_key.replace("'", "''")
        escaped_secret_key = secret_key.replace("'", "''")

        return f"s3('{escaped_url}', '{escaped_access_key}', '{escaped_secret_key}', 'JSONAsString')"

    def insert_raw_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert raw events into ClickHouse unified table"""
        if not events:
            return 0

        table_name = self.get_raw_events_table()

        # Transform events to the format expected by ClickHouse
        transformed_events = [self._transform_raw_event(event) for event in events]

        # Build INSERT query
        insert_query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            timestamp, event_type, attempt_guid, attempt_number, page_id,
            content_element_id, video_url, video_title, video_time, video_length,
            video_progress, video_played_segments, video_play_time, video_seek_from,
            video_seek_to, activity_attempt_guid, activity_attempt_number,
            page_attempt_guid, page_attempt_number, part_attempt_guid,
            part_attempt_number, activity_id, activity_revision_id, part_id,
            page_sub_type, score, out_of, scaled_score, success, completion,
            response, feedback, hints_requested, attached_objectives, session_id
        ) VALUES
        """

        # Format values for insertion
        values_list = []
        for event_data in transformed_events:
            values = [
                format_sql_value(event_data['event_id']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['host_name']),
                str(event_data['section_id']),
                str(event_data['project_id']),
                str(event_data['publication_id']),
                format_sql_value(event_data['timestamp']),
                format_sql_value(event_data['event_type']),
                format_sql_value(event_data['attempt_guid']),
                str(event_data['attempt_number']) if event_data['attempt_number'] is not None else 'NULL',
                str(event_data['page_id']) if event_data['page_id'] is not None else 'NULL',
                format_sql_value(event_data['content_element_id']),
                format_sql_value(event_data['video_url']),
                format_sql_value(event_data['video_title']),
                str(event_data['video_time']) if event_data['video_time'] is not None else 'NULL',
                str(event_data['video_length']) if event_data['video_length'] is not None else 'NULL',
                str(event_data['video_progress']) if event_data['video_progress'] is not None else 'NULL',
                format_sql_value(event_data['video_played_segments']),
                str(event_data['video_play_time']) if event_data['video_play_time'] is not None else 'NULL',
                str(event_data['video_seek_from']) if event_data['video_seek_from'] is not None else 'NULL',
                str(event_data['video_seek_to']) if event_data['video_seek_to'] is not None else 'NULL',
                format_sql_value(event_data['activity_attempt_guid']),
                str(event_data['activity_attempt_number']) if event_data['activity_attempt_number'] is not None else 'NULL',
                format_sql_value(event_data['page_attempt_guid']),
                str(event_data['page_attempt_number']) if event_data['page_attempt_number'] is not None else 'NULL',
                format_sql_value(event_data['part_attempt_guid']),
                str(event_data['part_attempt_number']) if event_data['part_attempt_number'] is not None else 'NULL',
                str(event_data['activity_id']) if event_data['activity_id'] is not None else 'NULL',
                str(event_data['activity_revision_id']) if event_data['activity_revision_id'] is not None else 'NULL',
                format_sql_value(event_data['part_id']),
                format_sql_value(event_data['page_sub_type']),
                str(event_data['score']) if event_data['score'] is not None else 'NULL',
                str(event_data['out_of']) if event_data['out_of'] is not None else 'NULL',
                str(event_data['scaled_score']) if event_data['scaled_score'] is not None else 'NULL',
                str(event_data['success']).lower() if event_data['success'] is not None else 'NULL',
                str(event_data['completion']).lower() if event_data['completion'] is not None else 'NULL',
                format_sql_value(event_data['response']),
                format_sql_value(event_data['feedback']),
                str(event_data['hints_requested']) if event_data['hints_requested'] is not None else 'NULL',
                format_sql_value(event_data['attached_objectives']),
                format_sql_value(event_data['session_id'])
            ]
            values_list.append(f"({', '.join(values)})")

        full_query = insert_query + ', '.join(values_list)

        try:
            self._execute_query(full_query)
            logger.info(f"Successfully inserted {len(events)} raw events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert raw events: {str(e)}")
            raise

    def _transform_raw_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI event to unified raw_events format"""
        # Extract basic fields
        event_id = event.get('id', str(uuid.uuid4()))

        # Convert timestamp
        raw_timestamp = event.get('timestamp', datetime.utcnow().isoformat())
        timestamp = format_clickhouse_timestamp(raw_timestamp)

        # Extract user information
        actor = event.get('actor', {})
        account = actor.get('account', {})
        user_id = account.get('name', '') or actor.get('mbox', '') or ''

        # Extract context extensions
        context = event.get('context', {})
        extensions = context.get('extensions', {})

        section_id = extensions.get('http://oli.cmu.edu/extensions/section_id', 0)
        project_id = extensions.get('http://oli.cmu.edu/extensions/project_id', 0)
        publication_id = extensions.get('http://oli.cmu.edu/extensions/publication_id', 0)
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Determine event type based on verb and object type
        verb_id = event.get('verb', {}).get('id', '')
        object_type = safe_get_nested(event, 'object.definition.type', '')

        # Ensure object_type is a string
        if not isinstance(object_type, str):
            object_type = str(object_type) if object_type is not None else ''

        # Determine event type
        event_type = self._determine_event_type(verb_id, object_type)

        # Initialize all fields as None/default
        base_data = {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'timestamp': timestamp,
            'event_type': event_type,
            'attempt_guid': None,
            'attempt_number': None,
            'page_id': None,
            'content_element_id': None,
            'video_url': None,
            'video_title': None,
            'video_time': None,
            'video_length': None,
            'video_progress': None,
            'video_played_segments': None,
            'video_play_time': None,
            'video_seek_from': None,
            'video_seek_to': None,
            'activity_attempt_guid': None,
            'activity_attempt_number': None,
            'page_attempt_guid': None,
            'page_attempt_number': None,
            'part_attempt_guid': None,
            'part_attempt_number': None,
            'activity_id': None,
            'activity_revision_id': None,
            'part_id': None,
            'page_sub_type': None,
            'score': None,
            'out_of': None,
            'scaled_score': None,
            'success': None,
            'completion': None,
            'response': None,
            'feedback': None,
            'hints_requested': None,
            'attached_objectives': None,
            'session_id': extensions.get('http://oli.cmu.edu/extensions/session_id')  # Set session_id for all events
        }

        # Populate type-specific fields
        if event_type == 'video':
            self._populate_video_fields(event, base_data, extensions)
        elif event_type == 'activity_attempt':
            self._populate_activity_attempt_fields(event, base_data, extensions)
        elif event_type == 'page_attempt':
            self._populate_page_attempt_fields(event, base_data, extensions)
        elif event_type == 'page_viewed':
            self._populate_page_viewed_fields(event, base_data, extensions)
        elif event_type == 'part_attempt':
            self._populate_part_attempt_fields(event, base_data, extensions)

        return base_data

    def _determine_event_type(self, verb_id: str, object_type: str) -> str:
        """Determine the event type based on verb and object type"""
        # Video events
        video_verbs = [
            'https://w3id.org/xapi/video/verbs/played',
            'https://w3id.org/xapi/video/verbs/paused',
            'https://w3id.org/xapi/video/verbs/seeked',
            'https://w3id.org/xapi/video/verbs/completed',
            'http://adlnet.gov/expapi/verbs/experienced'  # Legacy
        ]

        if verb_id in video_verbs:
            return 'video'

        # Activity attempt events
        if (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://oli.cmu.edu/extensions/activity_attempt'):
            return 'activity_attempt'

        # Page attempt events
        if (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://oli.cmu.edu/extensions/page_attempt'):
            return 'page_attempt'

        # Page viewed events
        if (verb_id == 'http://id.tincanapi.com/verb/viewed' and
            object_type == 'http://oli.cmu.edu/extensions/types/page'):
            return 'page_viewed'

        # Part attempt events
        if (verb_id == 'http://adlnet.gov/expapi/verbs/completed' and
            object_type == 'http://adlnet.gov/expapi/activities/question'):
            return 'part_attempt'

        return 'unknown'

    def _populate_video_fields(self, event: Dict[str, Any], base_data: Dict[str, Any], extensions: Dict[str, Any]):
        """Populate video-specific fields"""
        # Extract video-specific data
        obj = event.get('object', {})
        base_data['video_url'] = obj.get('id', '')
        base_data['video_title'] = safe_get_nested(obj, 'definition.name.en-US', '')

        # Extract result extensions (video data)
        result = event.get('result', {})
        result_extensions = result.get('extensions', {})

        # Extract object definition extensions (for video length)
        object_extensions = safe_get_nested(obj, 'definition.extensions', {}) or {}

        base_data['content_element_id'] = (
            result_extensions.get('content_element_id', '') or
            extensions.get('http://oli.cmu.edu/extensions/content_element_id', '')
        )

        # Video metrics
        base_data['video_time'] = safe_float_convert(
            result_extensions.get('https://w3id.org/xapi/video/extensions/time')
        )
        base_data['video_length'] = safe_float_convert(
            result_extensions.get('https://w3id.org/xapi/video/extensions/length') or
            extensions.get('https://w3id.org/xapi/video/extensions/length') or
            object_extensions.get('https://w3id.org/xapi/video/extensions/length')
        )
        base_data['video_progress'] = safe_float_convert(
            result_extensions.get('https://w3id.org/xapi/video/extensions/progress')
        )
        base_data['video_played_segments'] = result_extensions.get(
            'https://w3id.org/xapi/video/extensions/played-segments'
        )
        base_data['video_play_time'] = safe_float_convert(
            result_extensions.get('video_play_time')
        )
        base_data['video_seek_from'] = safe_float_convert(
            result_extensions.get('https://w3id.org/xapi/video/extensions/time-from')
        )
        base_data['video_seek_to'] = safe_float_convert(
            result_extensions.get('https://w3id.org/xapi/video/extensions/time-to')
        )

        # Common fields for video events
        base_data['attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/attempt_guid', '')
        base_data['attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/attempt_number')
        )
        base_data['page_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/page_id'))

    def _populate_activity_attempt_fields(self, event: Dict[str, Any], base_data: Dict[str, Any], extensions: Dict[str, Any]):
        """Populate activity attempt-specific fields"""
        base_data['activity_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_guid', '')
        base_data['activity_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/activity_attempt_number')
        )
        base_data['page_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        base_data['page_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/page_attempt_number')
        )
        base_data['page_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/page_id'))
        base_data['activity_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/activity_id'))
        base_data['activity_revision_id'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/activity_revision_id')
        )

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        base_data['score'] = safe_float_convert(score_data.get('raw'))
        base_data['out_of'] = safe_float_convert(score_data.get('max'))
        base_data['scaled_score'] = safe_float_convert(score_data.get('scaled'))
        base_data['success'] = result.get('success')
        base_data['completion'] = result.get('completion')

    def _populate_page_attempt_fields(self, event: Dict[str, Any], base_data: Dict[str, Any], extensions: Dict[str, Any]):
        """Populate page attempt-specific fields"""
        base_data['page_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        base_data['page_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/page_attempt_number')
        )
        base_data['page_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/page_id'))

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        base_data['score'] = safe_float_convert(score_data.get('raw'))
        base_data['out_of'] = safe_float_convert(score_data.get('max'))
        base_data['scaled_score'] = safe_float_convert(score_data.get('scaled'))
        base_data['success'] = result.get('success')
        base_data['completion'] = result.get('completion')

    def _populate_page_viewed_fields(self, event: Dict[str, Any], base_data: Dict[str, Any], extensions: Dict[str, Any]):
        """Populate page viewed-specific fields"""
        base_data['page_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        base_data['page_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/page_attempt_number')
        )
        base_data['page_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/page_id'))

        # Extract page sub type
        base_data['page_sub_type'] = safe_get_nested(event, 'object.definition.subType', '')

        # Extract result data
        result = event.get('result', {})
        base_data['success'] = result.get('success')
        base_data['completion'] = result.get('completion')

    def _populate_part_attempt_fields(self, event: Dict[str, Any], base_data: Dict[str, Any], extensions: Dict[str, Any]):
        """Populate part attempt-specific fields"""
        base_data['part_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/part_attempt_guid', '')
        base_data['part_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/part_attempt_number')
        )
        base_data['activity_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_guid', '')
        base_data['activity_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/activity_attempt_number')
        )
        base_data['page_attempt_guid'] = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        base_data['page_attempt_number'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/page_attempt_number')
        )
        base_data['page_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/page_id'))
        base_data['activity_id'] = safe_int_convert(extensions.get('http://oli.cmu.edu/extensions/activity_id'))
        base_data['activity_revision_id'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/activity_revision_id')
        )
        base_data['part_id'] = extensions.get('http://oli.cmu.edu/extensions/part_id', '')
        base_data['hints_requested'] = safe_int_convert(
            extensions.get('http://oli.cmu.edu/extensions/hints_requested')
        )
        base_data['session_id'] = extensions.get('http://oli.cmu.edu/extensions/session_id')

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        base_data['score'] = safe_float_convert(score_data.get('raw'))
        base_data['out_of'] = safe_float_convert(score_data.get('max'))
        base_data['scaled_score'] = safe_float_convert(score_data.get('scaled'))
        base_data['success'] = result.get('success')
        base_data['completion'] = result.get('completion')
        base_data['response'] = result.get('response')

        # Extract feedback from result extensions
        result_extensions = result.get('extensions', {})
        base_data['feedback'] = result_extensions.get('http://oli.cmu.edu/extensions/feedback')

        # Convert attached_objectives to JSON string if it's a list
        attached_objectives = extensions.get('http://oli.cmu.edu/extensions/attached_objectives')
        if attached_objectives is not None:
            if isinstance(attached_objectives, list):
                base_data['attached_objectives'] = json.dumps(attached_objectives)
            else:
                base_data['attached_objectives'] = str(attached_objectives)

    def get_section_event_count(self, section_id: int) -> int:
        """Get the total count of events for a specific section"""
        table_name = self.get_raw_events_table()
        query = f"SELECT COUNT(*) FROM {table_name} WHERE section_id = {section_id}"

        try:
            response = self._execute_query(query)
            return int(response.text.strip())
        except Exception as e:
            logger.error(f"Failed to get event count for section {section_id}: {str(e)}")
            return 0

    def get_section_event_count_by_type(self, section_id: int) -> Dict[str, int]:
        """Get the count of events by type for a specific section"""
        table_name = self.get_raw_events_table()
        query = f"""
        SELECT event_type, COUNT(*) as count
        FROM {table_name}
        WHERE section_id = {section_id}
        GROUP BY event_type
        ORDER BY event_type
        """

        try:
            response = self._execute_query(query)
            results = {}
            for line in response.text.strip().split('\n'):
                if line:
                    parts = line.split('\t')
                    if len(parts) == 2:
                        event_type, count = parts
                        results[event_type] = int(count)
            return results
        except Exception as e:
            logger.error(f"Failed to get event count by type for section {section_id}: {str(e)}")
            return {}

    def delete_section_events(self, section_id: int, before_timestamp: Optional[str] = None) -> int:
        """Delete events for a specific section, optionally before a timestamp"""
        table_name = self.get_raw_events_table()

        where_clause = f"section_id = {section_id}"
        if before_timestamp:
            where_clause += f" AND timestamp < '{before_timestamp}'"

        query = f"ALTER TABLE {table_name} DELETE WHERE {where_clause}"

        try:
            self._execute_query(query)
            logger.info(f"Deleted events for section {section_id} from {table_name}")
            return 1
        except Exception as e:
            logger.error(f"Failed to delete section events: {str(e)}")
            raise

    def bulk_insert_from_s3(self, s3_paths: List[str], section_id: Optional[int] = None) -> Dict[str, int]:
        """
        Use ClickHouse's S3 integration to directly insert data from S3 JSONL files
        into the unified raw_events table
        """
        if not s3_paths:
            return {'total_events_processed': 0}

        logger.info(f"Processing {len(s3_paths)} files via ClickHouse S3 integration into unified raw_events table")

        # Batch size to avoid max_query_size limit
        BATCH_SIZE = 50

        results = {
            'video_events_processed': 0,
            'activity_attempt_events_processed': 0,
            'page_attempt_events_processed': 0,
            'page_viewed_events_processed': 0,
            'part_attempt_events_processed': 0,
            'total_events_processed': 0
        }

        # Process files in batches
        total_batches = (len(s3_paths) + BATCH_SIZE - 1) // BATCH_SIZE
        logger.info(f"Processing {len(s3_paths)} files in {total_batches} batches of up to {BATCH_SIZE} files each")

        try:
            for i in range(0, len(s3_paths), BATCH_SIZE):
                batch_paths = s3_paths[i:i + BATCH_SIZE]
                batch_num = (i // BATCH_SIZE) + 1

                logger.info(f"Processing batch {batch_num}/{total_batches} with {len(batch_paths)} files")

                # Process each file individually in this batch
                for s3_path in batch_paths:
                    file_results = self._process_single_s3_file_unified(s3_path, section_id)
                    for key in results:
                        results[key] += file_results.get(key, 0)

                logger.info(f"Batch {batch_num} completed")

        except Exception as e:
            logger.error(f"Error in bulk S3 processing: {str(e)}")
            raise

        logger.info(f"S3 integration complete: {results['total_events_processed']} total events processed")
        return results

    def _process_single_s3_file_unified(self, s3_path: str, section_id: Optional[int] = None) -> Dict[str, int]:
        """Process a single S3 file into the unified raw_events table"""
        table_name = self.get_raw_events_table()

        # Base WHERE clause to filter valid events (use s.json with JSONAsString format)
        # XAPI statements don't always have 'id' field, so filter by verb.id instead
        # Use JSON_VALUE instead of JSONExtractString for JSONAsString format
        where_conditions = ["JSON_VALUE(s.json, '$.verb.id') != ''"]  # Ensure valid XAPI verb

        if section_id:
            # Use JSON_VALUE with the extensions object and proper path
            where_conditions.append(f"toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/section_id\"')) = {section_id}")

        where_clause = " AND ".join(where_conditions)

        # Single INSERT query for all event types into unified table
        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            timestamp, event_type, attempt_guid, attempt_number, page_id,
            content_element_id, video_url, video_title, video_time, video_length,
            video_progress, video_played_segments, video_play_time, video_seek_from,
            video_seek_to, activity_attempt_guid, activity_attempt_number,
            page_attempt_guid, page_attempt_number, part_attempt_guid,
            part_attempt_number, activity_id, activity_revision_id, part_id,
            page_sub_type, score, out_of, scaled_score, success, completion,
            response, feedback, hints_requested, attached_objectives, session_id
        )
        SELECT
            -- Generate a UUID for event_id since XAPI statements don't always have 'id' field
            generateUUIDv4(),
            COALESCE(
                JSON_VALUE(s.json, '$.actor.account.name'),
                JSON_VALUE(s.json, '$.actor.mbox'),
                ''
            ),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/host_name\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/section_id\"')),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/project_id\"')),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/publication_id\"')),
            replaceAll(JSON_VALUE(s.json, '$.timestamp'), 'Z', ''),

            -- Determine event type based on verb and object type
            multiIf(
                JSON_VALUE(s.json, '$.verb.id') IN (
                    'https://w3id.org/xapi/video/verbs/played',
                    'https://w3id.org/xapi/video/verbs/paused',
                    'https://w3id.org/xapi/video/verbs/seeked',
                    'https://w3id.org/xapi/video/verbs/completed',
                    'http://adlnet.gov/expapi/verbs/experienced'
                ), 'video',

                (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/activity_attempt'), 'activity_attempt',

                (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/page_attempt'), 'page_attempt',

                (JSON_VALUE(s.json, '$.verb.id') = 'http://id.tincanapi.com/verb/viewed') AND
                (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/types/page'), 'page_viewed',

                (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                (JSON_VALUE(s.json, '$.object.definition.type') = 'http://adlnet.gov/expapi/activities/question'), 'part_attempt',

                'unknown'
            ),

            -- Common fields
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/attempt_guid\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/attempt_number\"')),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/page_id\"')),

            -- Video-specific fields
            COALESCE(
                JSON_VALUE(s.json, '$.result.extensions.content_element_id'),
                JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/content_element_id\"'),
                NULL
            ),
            JSON_VALUE(s.json, '$.object.id'),
            JSON_VALUE(s.json, '$.object.definition.name.\"en-US\"'),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time\"')),
            COALESCE(
                toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/length\"')),
                toFloat64OrZero(JSON_VALUE(s.json, '$.context.extensions.\"https://w3id.org/xapi/video/extensions/length\"'))
            ),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/progress\"')),
            JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/played-segments\"'),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.video_play_time')),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time-from\"')),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time-to\"')),

            -- Activity/Page/Part specific fields
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/activity_attempt_guid\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/activity_attempt_number\"')),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/page_attempt_guid\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/page_attempt_number\"')),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/part_attempt_guid\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/part_attempt_number\"')),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/activity_id\"')),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/activity_revision_id\"')),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/part_id\"'),

            -- Page-specific fields
            JSON_VALUE(s.json, '$.object.definition.subType'),

            -- Result fields
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.score.raw')),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.score.max')),
            toFloat64OrZero(JSON_VALUE(s.json, '$.result.score.scaled')),
            toUInt8OrZero(JSON_VALUE(s.json, '$.result.success')) = 1,
            toUInt8OrZero(JSON_VALUE(s.json, '$.result.completion')) = 1,
            JSON_VALUE(s.json, '$.result.response'),
            JSON_VALUE(s.json, '$.result.extensions.\"http://oli.cmu.edu/extensions/feedback\"'),
            toInt32OrZero(JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/hints_requested\"')),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/attached_objectives\"'),
            JSON_VALUE(s.json, '$.context.extensions.\"http://oli.cmu.edu/extensions/session_id\"')

        FROM {self._build_s3_function_call(s3_path)} AS s
        WHERE {where_clause}
        """

        try:
            self._execute_query(query)

            # Count events by type (use s.json with JSONAsString format)
            count_query = f"""
            SELECT
                multiIf(
                    JSON_VALUE(s.json, '$.verb.id') IN (
                        'https://w3id.org/xapi/video/verbs/played',
                        'https://w3id.org/xapi/video/verbs/paused',
                        'https://w3id.org/xapi/video/verbs/seeked',
                        'https://w3id.org/xapi/video/verbs/completed',
                        'http://adlnet.gov/expapi/verbs/experienced'
                    ), 'video',

                    (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                    (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/activity_attempt'), 'activity_attempt',

                    (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                    (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/page_attempt'), 'page_attempt',

                    (JSON_VALUE(s.json, '$.verb.id') = 'http://id.tincanapi.com/verb/viewed') AND
                    (JSON_VALUE(s.json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/types/page'), 'page_viewed',

                    (JSON_VALUE(s.json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed') AND
                    (JSON_VALUE(s.json, '$.object.definition.type') = 'http://adlnet.gov/expapi/activities/question'), 'part_attempt',

                    'unknown'
                ) as event_type,
                COUNT(*) as count
            FROM {self._build_s3_function_call(s3_path)} AS s
            WHERE {where_clause}
            GROUP BY event_type
            """

            count_response = self._execute_query(count_query)

            # Parse the results
            results = {
                'video_events_processed': 0,
                'activity_attempt_events_processed': 0,
                'page_attempt_events_processed': 0,
                'page_viewed_events_processed': 0,
                'part_attempt_events_processed': 0,
                'total_events_processed': 0
            }

            for line in count_response.text.strip().split('\n'):
                if line:
                    parts = line.split('\t')
                    if len(parts) == 2:
                        event_type, count = parts
                        count = int(count)
                        results['total_events_processed'] += count

                        if event_type == 'video':
                            results['video_events_processed'] = count
                        elif event_type == 'activity_attempt':
                            results['activity_attempt_events_processed'] = count
                        elif event_type == 'page_attempt':
                            results['page_attempt_events_processed'] = count
                        elif event_type == 'page_viewed':
                            results['page_viewed_events_processed'] = count
                        elif event_type == 'part_attempt':
                            results['part_attempt_events_processed'] = count

            logger.info(f"Inserted {results['total_events_processed']} events from {s3_path}")
            return results

        except Exception as e:
            logger.error(f"Failed to process S3 file {s3_path}: {str(e)}")
            raise
