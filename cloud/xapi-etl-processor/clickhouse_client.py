"""
ClickHouse client for XAPI ETL pipeline
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
        self.aws_config = config.get('aws', {})  # Use .get() to handle missing aws config
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

    def get_video_events_table(self) -> str:
        """Get the fully qualified video events table name"""
        return f"{self.database}.video_events"

    def get_activity_attempt_events_table(self) -> str:
        """Get the fully qualified activity attempt events table name"""
        return f"{self.database}.activity_attempt_events"

    def get_page_attempt_events_table(self) -> str:
        """Get the fully qualified page attempt events table name"""
        return f"{self.database}.page_attempt_events"

    def get_page_viewed_events_table(self) -> str:
        """Get the fully qualified page viewed events table name"""
        return f"{self.database}.page_viewed_events"

    def get_part_attempt_events_table(self) -> str:
        """Get the fully qualified part attempt events table name"""
        return f"{self.database}.part_attempt_events"

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

        # Use single quotes for ClickHouse string literals and escape any single quotes in the values
        escaped_path = s3_path.replace("'", "''")
        escaped_access_key = access_key.replace("'", "''")
        escaped_secret_key = secret_key.replace("'", "''")

        return f"s3('{escaped_path}', '{escaped_access_key}', '{escaped_secret_key}', 'JSONEachRow')"

    def insert_video_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert video events into ClickHouse"""
        if not events:
            return 0

        table_name = self.get_video_events_table()

        # Transform events to the format expected by ClickHouse
        transformed_events = [self._transform_video_event(event) for event in events]

        # Build INSERT query
        insert_query = f"""
        INSERT INTO {table_name} (
            event_id,
            user_id,
            host_name,
            section_id,
            project_id,
            publication_id,
            attempt_guid,
            attempt_number,
            page_id,
            content_element_id,
            timestamp,
            video_url,
            video_title,
            video_time,
            video_length,
            video_progress,
            video_played_segments,
            video_play_time,
            video_seek_from,
            video_seek_to
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
                format_sql_value(event_data['attempt_guid']),
                str(event_data['attempt_number']),
                str(event_data['page_id']) if event_data['page_id'] is not None else 'NULL',
                format_sql_value(event_data['content_element_id']),
                format_sql_value(event_data['timestamp']),
                format_sql_value(event_data['video_url']),
                format_sql_value(event_data['video_title']),
                str(event_data['video_time']) if event_data['video_time'] is not None else 'NULL',
                str(event_data['video_length']) if event_data['video_length'] is not None else 'NULL',
                str(event_data['video_progress']) if event_data['video_progress'] is not None else 'NULL',
                format_sql_value(event_data['video_played_segments']),
                str(event_data['video_play_time']) if event_data['video_play_time'] is not None else 'NULL',
                str(event_data['video_seek_from']) if event_data['video_seek_from'] is not None else 'NULL',
                str(event_data['video_seek_to']) if event_data['video_seek_to'] is not None else 'NULL'
            ]
            values_list.append(f"({', '.join(values)})")

        full_query = insert_query + ', '.join(values_list)

        try:
            self._execute_query(full_query)
            logger.info(f"Successfully inserted {len(events)} video events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert video events: {str(e)}")
            raise

    def insert_activity_attempt_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert activity attempt events into ClickHouse"""
        if not events:
            return 0

        table_name = self.get_activity_attempt_events_table()
        transformed_events = [self._transform_activity_attempt_event(event) for event in events]

        insert_query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            activity_attempt_guid, activity_attempt_number, page_attempt_guid,
            page_attempt_number, page_id, activity_id, activity_revision_id,
            timestamp, score, out_of, scaled_score, success, completion
        ) VALUES
        """

        values_list = []
        for event_data in transformed_events:
            values = [
                format_sql_value(event_data['event_id']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['host_name']),
                str(event_data['section_id']),
                str(event_data['project_id']),
                str(event_data['publication_id']),
                format_sql_value(event_data['activity_attempt_guid']),
                str(event_data['activity_attempt_number']),
                format_sql_value(event_data['page_attempt_guid']),
                str(event_data['page_attempt_number']),
                str(event_data['page_id']),
                str(event_data['activity_id']),
                str(event_data['activity_revision_id']),
                format_sql_value(event_data['timestamp']),
                str(event_data['score']) if event_data['score'] is not None else 'NULL',
                str(event_data['out_of']) if event_data['out_of'] is not None else 'NULL',
                str(event_data['scaled_score']) if event_data['scaled_score'] is not None else 'NULL',
                str(event_data['success']).lower() if event_data['success'] is not None else 'NULL',
                str(event_data['completion']).lower() if event_data['completion'] is not None else 'NULL'
            ]
            values_list.append(f"({', '.join(values)})")

        full_query = insert_query + ', '.join(values_list)

        try:
            self._execute_query(full_query)
            logger.info(f"Successfully inserted {len(events)} activity attempt events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert activity attempt events: {str(e)}")
            raise

    def insert_page_attempt_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert page attempt events into ClickHouse"""
        if not events:
            return 0

        table_name = self.get_page_attempt_events_table()
        transformed_events = [self._transform_page_attempt_event(event) for event in events]

        insert_query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            page_attempt_guid, page_attempt_number, page_id, timestamp,
            score, out_of, scaled_score, success, completion
        ) VALUES
        """

        values_list = []
        for event_data in transformed_events:
            values = [
                format_sql_value(event_data['event_id']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['host_name']),
                str(event_data['section_id']),
                str(event_data['project_id']),
                str(event_data['publication_id']),
                format_sql_value(event_data['page_attempt_guid']),
                str(event_data['page_attempt_number']),
                str(event_data['page_id']),
                format_sql_value(event_data['timestamp']),
                str(event_data['score']) if event_data['score'] is not None else 'NULL',
                str(event_data['out_of']) if event_data['out_of'] is not None else 'NULL',
                str(event_data['scaled_score']) if event_data['scaled_score'] is not None else 'NULL',
                str(event_data['success']).lower() if event_data['success'] is not None else 'NULL',
                str(event_data['completion']).lower() if event_data['completion'] is not None else 'NULL'
            ]
            values_list.append(f"({', '.join(values)})")

        full_query = insert_query + ', '.join(values_list)

        try:
            self._execute_query(full_query)
            logger.info(f"Successfully inserted {len(events)} page attempt events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert page attempt events: {str(e)}")
            raise

    def insert_page_viewed_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert page viewed events into ClickHouse"""
        if not events:
            return 0

        table_name = self.get_page_viewed_events_table()
        transformed_events = [self._transform_page_viewed_event(event) for event in events]

        insert_query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            page_attempt_guid, page_attempt_number, page_id, page_sub_type,
            timestamp, success, completion
        ) VALUES
        """

        values_list = []
        for event_data in transformed_events:
            values = [
                format_sql_value(event_data['event_id']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['host_name']),
                str(event_data['section_id']),
                str(event_data['project_id']),
                str(event_data['publication_id']),
                format_sql_value(event_data['page_attempt_guid']),
                str(event_data['page_attempt_number']),
                str(event_data['page_id']),
                format_sql_value(event_data['page_sub_type']),
                format_sql_value(event_data['timestamp']),
                str(event_data['success']).lower() if event_data['success'] is not None else 'NULL',
                str(event_data['completion']).lower() if event_data['completion'] is not None else 'NULL'
            ]
            values_list.append(f"({', '.join(values)})")

        full_query = insert_query + ', '.join(values_list)

        try:
            self._execute_query(full_query)
            logger.info(f"Successfully inserted {len(events)} page viewed events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert page viewed events: {str(e)}")
            raise

    def insert_part_attempt_events(self, events: List[Dict[str, Any]]) -> int:
        """Insert part attempt events into ClickHouse"""
        if not events:
            return 0

        table_name = self.get_part_attempt_events_table()
        transformed_events = [self._transform_part_attempt_event(event) for event in events]

        insert_query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            part_attempt_guid, part_attempt_number, activity_attempt_guid,
            activity_attempt_number, page_attempt_guid, page_attempt_number,
            page_id, activity_id, activity_revision_id, part_id, timestamp,
            score, out_of, scaled_score, success, completion, response,
            feedback, hints_requested, attached_objectives, session_id
        ) VALUES
        """

        values_list = []
        for event_data in transformed_events:
            values = [
                format_sql_value(event_data['event_id']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['host_name']),
                str(event_data['section_id']),
                str(event_data['project_id']),
                str(event_data['publication_id']),
                format_sql_value(event_data['part_attempt_guid']),
                str(event_data['part_attempt_number']),
                format_sql_value(event_data['activity_attempt_guid']),
                str(event_data['activity_attempt_number']),
                format_sql_value(event_data['page_attempt_guid']),
                str(event_data['page_attempt_number']),
                str(event_data['page_id']),
                str(event_data['activity_id']),
                str(event_data['activity_revision_id']),
                format_sql_value(event_data['part_id']),
                format_sql_value(event_data['timestamp']),
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
            logger.info(f"Successfully inserted {len(events)} part attempt events into ClickHouse")
            return len(events)
        except Exception as e:
            logger.error(f"Failed to insert part attempt events: {str(e)}")
            raise

    def _transform_video_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI video event to ClickHouse format"""
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
        attempt_guid = extensions.get('http://oli.cmu.edu/extensions/attempt_guid', '')
        attempt_number = extensions.get('http://oli.cmu.edu/extensions/attempt_number', 0)
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id')
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Extract video-specific data
        obj = event.get('object', {})
        video_url = obj.get('id', '')
        video_title = safe_get_nested(obj, 'definition.name.en-US', '')

        # Extract result extensions (video data)
        result = event.get('result', {})
        result_extensions = result.get('extensions', {})

        content_element_id = result_extensions.get('content_element_id', '') or extensions.get('http://oli.cmu.edu/extensions/content_element_id', '')

        # Video metrics
        video_time = result_extensions.get('https://w3id.org/xapi/video/extensions/time')
        video_length = result_extensions.get('https://w3id.org/xapi/video/extensions/length') or extensions.get('https://w3id.org/xapi/video/extensions/length')
        video_progress = result_extensions.get('https://w3id.org/xapi/video/extensions/progress')
        video_played_segments = result_extensions.get('https://w3id.org/xapi/video/extensions/played-segments')
        video_play_time = result_extensions.get('video_play_time')
        video_seek_from = result_extensions.get('https://w3id.org/xapi/video/extensions/time-from')
        video_seek_to = result_extensions.get('https://w3id.org/xapi/video/extensions/time-to')

        return {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'attempt_guid': attempt_guid,
            'attempt_number': safe_int_convert(attempt_number),
            'page_id': safe_int_convert(page_id),
            'content_element_id': content_element_id,
            'timestamp': timestamp,
            'video_url': video_url,
            'video_title': video_title,
            'video_time': safe_float_convert(video_time),
            'video_length': safe_float_convert(video_length),
            'video_progress': safe_float_convert(video_progress),
            'video_played_segments': video_played_segments,
            'video_play_time': safe_float_convert(video_play_time),
            'video_seek_from': safe_float_convert(video_seek_from),
            'video_seek_to': safe_float_convert(video_seek_to)
        }

    def _transform_activity_attempt_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI activity attempt event to ClickHouse format"""
        event_id = event.get('id', str(uuid.uuid4()))
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
        activity_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_guid', '')
        activity_attempt_number = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_number', 0)
        page_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        page_attempt_number = extensions.get('http://oli.cmu.edu/extensions/page_attempt_number', 0)
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id', 0)
        activity_id = extensions.get('http://oli.cmu.edu/extensions/activity_id', 0)
        activity_revision_id = extensions.get('http://oli.cmu.edu/extensions/activity_revision_id', 0)
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        score = score_data.get('raw')
        out_of = score_data.get('max')
        scaled_score = score_data.get('scaled')
        success = result.get('success')
        completion = result.get('completion')

        return {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'activity_attempt_guid': activity_attempt_guid,
            'activity_attempt_number': safe_int_convert(activity_attempt_number),
            'page_attempt_guid': page_attempt_guid,
            'page_attempt_number': safe_int_convert(page_attempt_number),
            'page_id': safe_int_convert(page_id),
            'activity_id': safe_int_convert(activity_id),
            'activity_revision_id': safe_int_convert(activity_revision_id),
            'timestamp': timestamp,
            'score': safe_float_convert(score),
            'out_of': safe_float_convert(out_of),
            'scaled_score': safe_float_convert(scaled_score),
            'success': success,
            'completion': completion
        }

    def _transform_page_attempt_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI page attempt event to ClickHouse format"""
        event_id = event.get('id', str(uuid.uuid4()))
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
        page_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        page_attempt_number = extensions.get('http://oli.cmu.edu/extensions/page_attempt_number', 0)
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id', 0)
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        score = score_data.get('raw')
        out_of = score_data.get('max')
        scaled_score = score_data.get('scaled')
        success = result.get('success')
        completion = result.get('completion')

        return {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'page_attempt_guid': page_attempt_guid,
            'page_attempt_number': safe_int_convert(page_attempt_number),
            'page_id': safe_int_convert(page_id),
            'timestamp': timestamp,
            'score': safe_float_convert(score),
            'out_of': safe_float_convert(out_of),
            'scaled_score': safe_float_convert(scaled_score),
            'success': success,
            'completion': completion
        }

    def _transform_page_viewed_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI page viewed event to ClickHouse format"""
        event_id = event.get('id', str(uuid.uuid4()))
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
        page_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        page_attempt_number = extensions.get('http://oli.cmu.edu/extensions/page_attempt_number', 0)
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id', 0)
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Extract page sub type
        page_sub_type = safe_get_nested(event, 'object.definition.subType', '')

        # Extract result data
        result = event.get('result', {})
        success = result.get('success')
        completion = result.get('completion')

        return {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'page_attempt_guid': page_attempt_guid,
            'page_attempt_number': safe_int_convert(page_attempt_number),
            'page_id': safe_int_convert(page_id),
            'page_sub_type': page_sub_type,
            'timestamp': timestamp,
            'success': success,
            'completion': completion
        }

    def _transform_part_attempt_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform xAPI part attempt event to ClickHouse format"""
        event_id = event.get('id', str(uuid.uuid4()))
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
        part_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/part_attempt_guid', '')
        part_attempt_number = extensions.get('http://oli.cmu.edu/extensions/part_attempt_number', 0)
        activity_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_guid', '')
        activity_attempt_number = extensions.get('http://oli.cmu.edu/extensions/activity_attempt_number', 0)
        page_attempt_guid = extensions.get('http://oli.cmu.edu/extensions/page_attempt_guid', '')
        page_attempt_number = extensions.get('http://oli.cmu.edu/extensions/page_attempt_number', 0)
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id', 0)
        activity_id = extensions.get('http://oli.cmu.edu/extensions/activity_id', 0)
        activity_revision_id = extensions.get('http://oli.cmu.edu/extensions/activity_revision_id', 0)
        part_id = extensions.get('http://oli.cmu.edu/extensions/part_id', '')
        hints_requested = extensions.get('http://oli.cmu.edu/extensions/hints_requested', 0)
        attached_objectives = extensions.get('http://oli.cmu.edu/extensions/attached_objectives')
        session_id = extensions.get('http://oli.cmu.edu/extensions/session_id')
        host_name = extensions.get('http://oli.cmu.edu/extensions/host_name', '')

        # Extract result data
        result = event.get('result', {})
        score_data = result.get('score', {})
        score = score_data.get('raw')
        out_of = score_data.get('max')
        scaled_score = score_data.get('scaled')
        success = result.get('success')
        completion = result.get('completion')
        response = result.get('response')

        # Extract feedback from result extensions
        result_extensions = result.get('extensions', {})
        feedback = result_extensions.get('http://oli.cmu.edu/extensions/feedback')

        # Convert attached_objectives to JSON string if it's a list
        attached_objectives_str = None
        if attached_objectives is not None:
            if isinstance(attached_objectives, list):
                attached_objectives_str = json.dumps(attached_objectives)
            else:
                attached_objectives_str = str(attached_objectives)

        return {
            'event_id': event_id,
            'user_id': user_id,
            'host_name': host_name,
            'section_id': safe_int_convert(section_id),
            'project_id': safe_int_convert(project_id),
            'publication_id': safe_int_convert(publication_id),
            'part_attempt_guid': part_attempt_guid,
            'part_attempt_number': safe_int_convert(part_attempt_number),
            'activity_attempt_guid': activity_attempt_guid,
            'activity_attempt_number': safe_int_convert(activity_attempt_number),
            'page_attempt_guid': page_attempt_guid,
            'page_attempt_number': safe_int_convert(page_attempt_number),
            'page_id': safe_int_convert(page_id),
            'activity_id': safe_int_convert(activity_id),
            'activity_revision_id': safe_int_convert(activity_revision_id),
            'part_id': part_id,
            'timestamp': timestamp,
            'score': safe_float_convert(score),
            'out_of': safe_float_convert(out_of),
            'scaled_score': safe_float_convert(scaled_score),
            'success': success,
            'completion': completion,
            'response': response,
            'feedback': feedback,
            'hints_requested': safe_int_convert(hints_requested) if hints_requested is not None else None,
            'attached_objectives': attached_objectives_str,
            'session_id': session_id
        }

    def get_section_event_count(self, section_id: int) -> int:
        """Get the total count of events for a specific section across all event types"""
        tables = [
            self.get_video_events_table(),
            self.get_activity_attempt_events_table(),
            self.get_page_attempt_events_table(),
            self.get_page_viewed_events_table(),
            self.get_part_attempt_events_table()
        ]

        total_count = 0
        for table in tables:
            query = f"SELECT COUNT(*) FROM {table} WHERE section_id = {section_id}"
            try:
                response = self._execute_query(query)
                count = int(response.text.strip())
                total_count += count
            except Exception as e:
                logger.warning(f"Failed to get event count from {table}: {str(e)}")
                # Continue with other tables
                continue

        return total_count

    def delete_section_events(self, section_id: int, before_timestamp: Optional[str] = None) -> int:
        """Delete events for a specific section from all event tables, optionally before a timestamp"""
        tables = [
            self.get_video_events_table(),
            self.get_activity_attempt_events_table(),
            self.get_page_attempt_events_table(),
            self.get_page_viewed_events_table(),
            self.get_part_attempt_events_table()
        ]

        deleted_count = 0
        for table in tables:
            where_clause = f"section_id = {section_id}"
            if before_timestamp:
                where_clause += f" AND timestamp < '{before_timestamp}'"

            query = f"ALTER TABLE {table} DELETE WHERE {where_clause}"

            try:
                self._execute_query(query)
                deleted_count += 1
                logger.info(f"Deleted events for section {section_id} from {table}")
            except Exception as e:
                logger.error(f"Failed to delete section events from {table}: {str(e)}")
                # Continue with other tables
                continue

        return deleted_count

    def bulk_insert_from_s3(self, s3_paths: List[str], section_id: Optional[int] = None) -> Dict[str, int]:
        """
        Use ClickHouse's S3 integration to directly insert data from S3 JSONL files
        This bypasses Lambda's limitations for bulk processing

        For large file sets, processes in batches to avoid ClickHouse query size limits
        """
        if not s3_paths:
            return {'total_events_processed': 0}

        logger.info(f"Processing {len(s3_paths)} files via ClickHouse S3 integration")

        # Batch size to avoid max_query_size limit (approximately 50-100 files per batch)
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

                # Process each file individually in this batch to avoid S3 function syntax issues
                batch_results = {
                    'video_events_processed': 0,
                    'activity_attempt_events_processed': 0,
                    'page_attempt_events_processed': 0,
                    'page_viewed_events_processed': 0,
                    'part_attempt_events_processed': 0,
                    'total_events_processed': 0
                }

                for s3_path in batch_paths:
                    file_results = self._process_single_s3_file(s3_path, section_id)
                    for key in batch_results:
                        batch_results[key] += file_results.get(key, 0)

                # Accumulate results
                for key in results:
                    results[key] += batch_results.get(key, 0)

                logger.info(f"Batch {batch_num} completed: {batch_results.get('total_events_processed', 0)} events processed")

        except Exception as e:
            logger.error(f"Error in bulk S3 processing: {str(e)}")
            raise

        logger.info(f"S3 integration complete: {results['total_events_processed']} total events processed")
        return results

    def _process_single_s3_file(self, s3_path: str, section_id: Optional[int] = None) -> Dict[str, int]:
        """Process a single S3 file"""
        file_results = {
            'video_events_processed': 0,
            'activity_attempt_events_processed': 0,
            'page_attempt_events_processed': 0,
            'page_viewed_events_processed': 0,
            'part_attempt_events_processed': 0,
            'total_events_processed': 0
        }

        try:
            # Process video events
            video_count = self._insert_video_events_from_s3_single(s3_path, section_id)
            file_results['video_events_processed'] = video_count

            # Process activity attempt events
            activity_count = self._insert_activity_attempt_events_from_s3_single(s3_path, section_id)
            file_results['activity_attempt_events_processed'] = activity_count

            # Process page attempt events
            page_attempt_count = self._insert_page_attempt_events_from_s3_single(s3_path, section_id)
            file_results['page_attempt_events_processed'] = page_attempt_count

            # Process page viewed events
            page_viewed_count = self._insert_page_viewed_events_from_s3_single(s3_path, section_id)
            file_results['page_viewed_events_processed'] = page_viewed_count

            # Process part attempt events
            part_attempt_count = self._insert_part_attempt_events_from_s3_single(s3_path, section_id)
            file_results['part_attempt_events_processed'] = part_attempt_count

            file_results['total_events_processed'] = (
                video_count + activity_count + page_attempt_count +
                page_viewed_count + part_attempt_count
            )

            return file_results

        except Exception as e:
            logger.error(f"Error processing single S3 file {s3_path}: {str(e)}")
            return file_results

    def _process_s3_batch(self, s3_union: str, section_id: Optional[int] = None) -> Dict[str, int]:
        """Process a single batch of S3 files"""
        batch_results = {
            'video_events_processed': 0,
            'activity_attempt_events_processed': 0,
            'page_attempt_events_processed': 0,
            'page_viewed_events_processed': 0,
            'part_attempt_events_processed': 0,
            'total_events_processed': 0
        }

        try:
            # Process video events
            video_count = self._insert_video_events_from_s3(s3_union, section_id)
            batch_results['video_events_processed'] = video_count

            # Process activity attempt events
            activity_count = self._insert_activity_attempt_events_from_s3(s3_union, section_id)
            batch_results['activity_attempt_events_processed'] = activity_count

            # Process page attempt events
            page_attempt_count = self._insert_page_attempt_events_from_s3(s3_union, section_id)
            batch_results['page_attempt_events_processed'] = page_attempt_count

            # Process page viewed events
            page_viewed_count = self._insert_page_viewed_events_from_s3(s3_union, section_id)
            batch_results['page_viewed_events_processed'] = page_viewed_count

            # Process part attempt events
            part_attempt_count = self._insert_part_attempt_events_from_s3(s3_union, section_id)
            batch_results['part_attempt_events_processed'] = part_attempt_count

            batch_results['total_events_processed'] = (
                video_count + activity_count + page_attempt_count +
                page_viewed_count + part_attempt_count
            )

            return batch_results

        except Exception as e:
            logger.error(f"Error processing S3 batch: {str(e)}")
            raise

    def _insert_video_events_from_s3(self, s3_union: str, section_id: Optional[int] = None) -> int:
        """Insert video events directly from S3 using ClickHouse S3 table function"""
        table_name = self.get_video_events_table()

        # Build the WHERE clause for video events
        where_conditions = [
            # Video event verbs
            "JSONExtractString(json, 'verb.id') IN ("
            "'https://w3id.org/xapi/video/verbs/played', "
            "'https://w3id.org/xapi/video/verbs/paused', "
            "'https://w3id.org/xapi/video/verbs/seeked', "
            "'https://w3id.org/xapi/video/verbs/completed', "
            "'http://adlnet.gov/expapi/verbs/experienced'"
            ")"
        ]

        if section_id:
            where_conditions.append(f"JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id') = {section_id}")

        where_clause = " AND ".join(where_conditions)

        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            attempt_guid, attempt_number, page_id, content_element_id, timestamp,
            video_url, video_title, video_time, video_length, video_progress,
            video_played_segments, video_play_time, video_seek_from, video_seek_to
        )
        SELECT
            JSONExtractString(json, 'id'),
            COALESCE(
                JSONExtractString(json, 'actor.account.name'),
                JSONExtractString(json, 'actor.mbox'),
                ''
            ),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/host_name'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/project_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/publication_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/attempt_number'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_id'),
            COALESCE(
                JSONExtractString(json, 'result.extensions.content_element_id'),
                JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/content_element_id'),
                ''
            ),
            replaceAll(JSONExtractString(json, 'timestamp'), 'Z', ''),
            JSONExtractString(json, 'object.id'),
            JSONExtractString(json, 'object.definition.name.en-US'),
            JSONExtractFloat(json, 'result.extensions.https://w3id.org/xapi/video/extensions/time'),
            COALESCE(
                JSONExtractFloat(json, 'result.extensions.https://w3id.org/xapi/video/extensions/length'),
                JSONExtractFloat(json, 'context.extensions.https://w3id.org/xapi/video/extensions/length')
            ),
            JSONExtractFloat(json, 'result.extensions.https://w3id.org/xapi/video/extensions/progress'),
            JSONExtractString(json, 'result.extensions.https://w3id.org/xapi/video/extensions/played-segments'),
            JSONExtractFloat(json, 'result.extensions.video_play_time'),
            JSONExtractFloat(json, 'result.extensions.https://w3id.org/xapi/video/extensions/time-from'),
            JSONExtractFloat(json, 'result.extensions.https://w3id.org/xapi/video/extensions/time-to')
        FROM s3({s3_union}, 'JSONAsString') AS s(json)
        WHERE {where_clause.replace('raw', 'json')}
        """

        try:
            response = self._execute_query(query)
            # ClickHouse doesn't return row count for INSERT, so we'll count separately
            count_query = f"""
            SELECT COUNT(*) FROM s3({s3_union}, 'JSONAsString') AS s(json)
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} video events from S3")
            return count
        except Exception as e:
            logger.error(f"Failed to insert video events from S3: {str(e)}")
            raise

    def _insert_activity_attempt_events_from_s3(self, s3_union: str, section_id: Optional[int] = None) -> int:
        """Insert activity attempt events directly from S3"""
        table_name = self.get_activity_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json, 'verb.id') = 'http://adlnet.gov/expapi/verbs/completed'",
            "JSONExtractString(json, 'object.definition.type') = 'http://oli.cmu.edu/extensions/activity_attempt'"
        ]

        if section_id:
            where_conditions.append(f"JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id') = {section_id}")

        where_clause = " AND ".join(where_conditions)

        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            activity_attempt_guid, activity_attempt_number, page_attempt_guid,
            page_attempt_number, page_id, activity_id, activity_revision_id,
            timestamp, score, out_of, scaled_score, success, completion
        )
        SELECT
            JSONExtractString(json, 'id'),
            COALESCE(
                JSONExtractString(json, 'actor.account.name'),
                JSONExtractString(json, 'actor.mbox'),
                ''
            ),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/host_name'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/project_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/publication_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_attempt_number'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_number'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_revision_id'),
            replaceAll(JSONExtractString(json, 'timestamp'), 'Z', ''),
            JSONExtractFloat(json, 'result.score.raw'),
            JSONExtractFloat(json, 'result.score.max'),
            JSONExtractFloat(json, 'result.score.scaled'),
            JSONExtractBool(json, 'result.success'),
            JSONExtractBool(json, 'result.completion')
        FROM s3({s3_union}, 'JSONAsString') AS s(json)
        WHERE {where_clause}
        """

        try:
            response = self._execute_query(query)
            count_query = f"""
            SELECT COUNT(*) FROM s3({s3_union}, 'JSONAsString') AS s(json)
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} activity attempt events from S3")
            return count
        except Exception as e:
            logger.error(f"Failed to insert activity attempt events from S3: {str(e)}")
            raise

    def _insert_page_attempt_events_from_s3(self, s3_union: str, section_id: Optional[int] = None) -> int:
        """Insert page attempt events directly from S3"""
        table_name = self.get_page_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json, 'verb.id') = 'http://adlnet.gov/expapi/verbs/completed'",
            "JSONExtractString(json, 'object.definition.type') = 'http://oli.cmu.edu/extensions/page_attempt'"
        ]

        if section_id:
            where_conditions.append(f"JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id') = {section_id}")

        where_clause = " AND ".join(where_conditions)

        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            page_attempt_guid, page_attempt_number, page_id, timestamp,
            score, out_of, scaled_score, success, completion
        )
        SELECT
            JSONExtractString(json, 'id'),
            COALESCE(
                JSONExtractString(json, 'actor.account.name'),
                JSONExtractString(json, 'actor.mbox'),
                ''
            ),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/host_name'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/project_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/publication_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_number'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_id'),
            replaceAll(JSONExtractString(json, 'timestamp'), 'Z', ''),
            JSONExtractFloat(json, 'result.score.raw'),
            JSONExtractFloat(json, 'result.score.max'),
            JSONExtractFloat(json, 'result.score.scaled'),
            JSONExtractBool(json, 'result.success'),
            JSONExtractBool(json, 'result.completion')
        FROM s3({s3_union}, 'JSONAsString') AS s(json)
        WHERE {where_clause}
        """

        try:
            response = self._execute_query(query)
            count_query = f"""
            SELECT COUNT(*) FROM s3({s3_union}, 'JSONAsString') AS s(json)
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} page attempt events from S3")
            return count
        except Exception as e:
            logger.error(f"Failed to insert page attempt events from S3: {str(e)}")
            raise

    def _insert_page_viewed_events_from_s3(self, s3_union: str, section_id: Optional[int] = None) -> int:
        """Insert page viewed events directly from S3"""
        table_name = self.get_page_viewed_events_table()

        where_conditions = [
            "JSONExtractString(json, 'verb.id') = 'http://id.tincanapi.com/verb/viewed'",
            "JSONExtractString(json, 'object.definition.type') = 'http://oli.cmu.edu/extensions/types/page'"
        ]

        if section_id:
            where_conditions.append(f"JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id') = {section_id}")

        where_clause = " AND ".join(where_conditions)

        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            page_attempt_guid, page_attempt_number, page_id, page_sub_type,
            timestamp, success, completion
        )
        SELECT
            JSONExtractString(json, 'id'),
            COALESCE(
                JSONExtractString(json, 'actor.account.name'),
                JSONExtractString(json, 'actor.mbox'),
                ''
            ),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/host_name'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/project_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/publication_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_number'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_id'),
            JSONExtractString(json, 'object.definition.subType'),
            replaceAll(JSONExtractString(json, 'timestamp'), 'Z', ''),
            JSONExtractBool(json, 'result.success'),
            JSONExtractBool(json, 'result.completion')
        FROM s3({s3_union}, 'JSONAsString') AS s(json)
        WHERE {where_clause}
        """

        try:
            response = self._execute_query(query)
            count_query = f"""
            SELECT COUNT(*) FROM s3({s3_union}, 'JSONAsString') AS s(json)
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} page viewed events from S3")
            return count
        except Exception as e:
            logger.error(f"Failed to insert page viewed events from S3: {str(e)}")
            raise

    def _insert_part_attempt_events_from_s3(self, s3_union: str, section_id: Optional[int] = None) -> int:
        """Insert part attempt events directly from S3"""
        table_name = self.get_part_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json, 'verb.id') = 'http://adlnet.gov/expapi/verbs/completed'",
            "JSONExtractString(json, 'object.definition.type') = 'http://adlnet.gov/expapi/activities/question'"
        ]

        if section_id:
            where_conditions.append(f"JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id') = {section_id}")

        where_clause = " AND ".join(where_conditions)

        query = f"""
        INSERT INTO {table_name} (
            event_id, user_id, host_name, section_id, project_id, publication_id,
            part_attempt_guid, part_attempt_number, activity_attempt_guid,
            activity_attempt_number, page_attempt_guid, page_attempt_number,
            page_id, activity_id, activity_revision_id, part_id, timestamp,
            score, out_of, scaled_score, success, completion, response,
            feedback, hints_requested, attached_objectives, session_id
        )
        SELECT
            JSONExtractString(json, 'id'),
            COALESCE(
                JSONExtractString(json, 'actor.account.name'),
                JSONExtractString(json, 'actor.mbox'),
                ''
            ),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/host_name'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/section_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/project_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/publication_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/part_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/part_attempt_number'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_attempt_number'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_guid'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_attempt_number'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/page_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_id'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/activity_revision_id'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/part_id'),
            replaceAll(JSONExtractString(json, 'timestamp'), 'Z', ''),
            JSONExtractFloat(json, 'result.score.raw'),
            JSONExtractFloat(json, 'result.score.max'),
            JSONExtractFloat(json, 'result.score.scaled'),
            JSONExtractBool(json, 'result.success'),
            JSONExtractBool(json, 'result.completion'),
            JSONExtractString(json, 'result.response'),
            JSONExtractString(json, 'result.extensions.http://oli.cmu.edu/extensions/feedback'),
            JSONExtractInt(json, 'context.extensions.http://oli.cmu.edu/extensions/hints_requested'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/attached_objectives'),
            JSONExtractString(json, 'context.extensions.http://oli.cmu.edu/extensions/session_id')
        FROM s3({s3_union}, 'JSONAsString') AS s(json)
        WHERE {where_clause}
        """

        try:
            response = self._execute_query(query)
            count_query = f"""
            SELECT COUNT(*) FROM s3({s3_union}, 'JSONAsString') AS s(json)
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} part attempt events from S3")
            return count
        except Exception as e:
            logger.error(f"Failed to insert part attempt events from S3: {str(e)}")
            raise

    def _insert_video_events_from_s3_single(self, s3_path: str, section_id: Optional[int] = None) -> int:
        """Insert video events from a single S3 file"""
        table_name = self.get_video_events_table()

        where_conditions = [
            "JSONExtractString(json_data, 'verb.id') = 'http://adlnet.gov/expapi/verbs/experienced'"
        ]

        if section_id:
            where_conditions.append(f"section_id = {section_id}")

        where_clause = " AND ".join(where_conditions)

        insert_query = f"""
        INSERT INTO {table_name}
        SELECT
            JSONExtractString(json_data, 'actor.account.name') as user_id,
            CAST(JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/video_duration') AS Float64) as video_duration,
            JSONExtractString(json_data, 'timestamp') as event_timestamp,
            {section_id if section_id else 'NULL'} as section_id,
            JSONExtractString(json_data, 'object.id') as video_id,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/video_time') as video_time,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/video_length') as video_length,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/progress') as progress,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/user_agent') as user_agent,
            JSONExtractString(json_data, 'verb.id') as verb_id
        FROM {self._build_s3_function_call(s3_path)}
        WHERE {where_clause}
        """

        try:
            self._execute_query(insert_query)
            # Count the inserted rows
            count_query = f"""
            SELECT COUNT(*) FROM {self._build_s3_function_call(s3_path)}
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} video events from S3 file {s3_path}")
            return count
        except Exception as e:
            logger.error(f"Failed to insert video events from S3 file {s3_path}: {str(e)}")
            raise

    def _insert_activity_attempt_events_from_s3_single(self, s3_path: str, section_id: Optional[int] = None) -> int:
        """Insert activity attempt events from a single S3 file"""
        table_name = self.get_activity_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json_data, 'verb.id') = 'http://adlnet.gov/expapi/verbs/answered'",
            "JSONExtractString(json_data, 'object.id') LIKE '%/activity/%'"
        ]

        if section_id:
            where_conditions.append(f"section_id = {section_id}")

        where_clause = " AND ".join(where_conditions)

        insert_query = f"""
        INSERT INTO {table_name}
        SELECT
            JSONExtractString(json_data, 'actor.account.name') as user_id,
            JSONExtractString(json_data, 'object.id') as activity_id,
            JSONExtractString(json_data, 'timestamp') as event_timestamp,
            {section_id if section_id else 'NULL'} as section_id,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/activity_attempt_guid') as activity_attempt_guid,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/out_of') as out_of,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/score') as score,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/user_agent') as user_agent,
            JSONExtractString(json_data, 'verb.id') as verb_id
        FROM {self._build_s3_function_call(s3_path)}
        WHERE {where_clause}
        """

        try:
            self._execute_query(insert_query)
            # Count the inserted rows
            count_query = f"""
            SELECT COUNT(*) FROM {self._build_s3_function_call(s3_path)}
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} activity attempt events from S3 file {s3_path}")
            return count
        except Exception as e:
            logger.error(f"Failed to insert activity attempt events from S3 file {s3_path}: {str(e)}")
            raise

    def _insert_page_attempt_events_from_s3_single(self, s3_path: str, section_id: Optional[int] = None) -> int:
        """Insert page attempt events from a single S3 file"""
        table_name = self.get_page_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json_data, 'verb.id') = 'http://adlnet.gov/expapi/verbs/answered'",
            "JSONExtractString(json_data, 'object.id') LIKE '%/page/%'"
        ]

        if section_id:
            where_conditions.append(f"section_id = {section_id}")

        where_clause = " AND ".join(where_conditions)

        insert_query = f"""
        INSERT INTO {table_name}
        SELECT
            JSONExtractString(json_data, 'actor.account.name') as user_id,
            JSONExtractString(json_data, 'object.id') as page_id,
            JSONExtractString(json_data, 'timestamp') as event_timestamp,
            {section_id if section_id else 'NULL'} as section_id,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/page_attempt_guid') as page_attempt_guid,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/out_of') as out_of,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/score') as score,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/user_agent') as user_agent,
            JSONExtractString(json_data, 'verb.id') as verb_id
        FROM {self._build_s3_function_call(s3_path)}
        WHERE {where_clause}
        """

        try:
            self._execute_query(insert_query)
            # Count the inserted rows
            count_query = f"""
            SELECT COUNT(*) FROM {self._build_s3_function_call(s3_path)}
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} page attempt events from S3 file {s3_path}")
            return count
        except Exception as e:
            logger.error(f"Failed to insert page attempt events from S3 file {s3_path}: {str(e)}")
            raise

    def _insert_page_viewed_events_from_s3_single(self, s3_path: str, section_id: Optional[int] = None) -> int:
        """Insert page viewed events from a single S3 file"""
        table_name = self.get_page_viewed_events_table()

        where_conditions = [
            "JSONExtractString(json_data, 'verb.id') = 'http://adlnet.gov/expapi/verbs/experienced'",
            "JSONExtractString(json_data, 'object.id') LIKE '%/page/%'"
        ]

        if section_id:
            where_conditions.append(f"section_id = {section_id}")

        where_clause = " AND ".join(where_conditions)

        insert_query = f"""
        INSERT INTO {table_name}
        SELECT
            JSONExtractString(json_data, 'actor.account.name') as user_id,
            JSONExtractString(json_data, 'object.id') as page_id,
            JSONExtractString(json_data, 'timestamp') as event_timestamp,
            {section_id if section_id else 'NULL'} as section_id,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/user_agent') as user_agent,
            JSONExtractString(json_data, 'verb.id') as verb_id
        FROM {self._build_s3_function_call(s3_path)}
        WHERE {where_clause}
        """

        try:
            self._execute_query(insert_query)
            # Count the inserted rows
            count_query = f"""
            SELECT COUNT(*) FROM {self._build_s3_function_call(s3_path)}
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} page viewed events from S3 file {s3_path}")
            return count
        except Exception as e:
            logger.error(f"Failed to insert page viewed events from S3 file {s3_path}: {str(e)}")
            raise

    def _insert_part_attempt_events_from_s3_single(self, s3_path: str, section_id: Optional[int] = None) -> int:
        """Insert part attempt events from a single S3 file"""
        table_name = self.get_part_attempt_events_table()

        where_conditions = [
            "JSONExtractString(json_data, 'verb.id') = 'http://adlnet.gov/expapi/verbs/answered'",
            "JSONExtractString(json_data, 'object.id') LIKE '%/part/%'"
        ]

        if section_id:
            where_conditions.append(f"section_id = {section_id}")

        where_clause = " AND ".join(where_conditions)

        insert_query = f"""
        INSERT INTO {table_name}
        SELECT
            JSONExtractString(json_data, 'actor.account.name') as user_id,
            JSONExtractString(json_data, 'object.id') as part_id,
            JSONExtractString(json_data, 'timestamp') as event_timestamp,
            {section_id if section_id else 'NULL'} as section_id,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/part_attempt_guid') as part_attempt_guid,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/attempt_number') as attempt_number,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/out_of') as out_of,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/score') as score,
            JSONExtractString(json_data, 'result.extensions.http://localhost:3000/extensions/user_agent') as user_agent,
            JSONExtractString(json_data, 'verb.id') as verb_id
        FROM {self._build_s3_function_call(s3_path)}
        WHERE {where_clause}
        """

        try:
            self._execute_query(insert_query)
            # Count the inserted rows
            count_query = f"""
            SELECT COUNT(*) FROM {self._build_s3_function_call(s3_path)}
            WHERE {where_clause}
            """
            count_response = self._execute_query(count_query)
            count = int(count_response.text.strip())
            logger.info(f"Inserted {count} part attempt events from S3 file {s3_path}")
            return count
        except Exception as e:
            logger.error(f"Failed to insert part attempt events from S3 file {s3_path}: {str(e)}")
            raise