"""
ClickHouse client for XAPI ETL pipeline
"""
import json
import logging
import requests
from typing import List, Dict, Any, Optional
from datetime import datetime
from common import get_config, format_clickhouse_timestamp, safe_get_nested, format_sql_value
import uuid

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
        self.config = get_config()['clickhouse']
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
