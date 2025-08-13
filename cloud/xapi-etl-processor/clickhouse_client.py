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
            timestamp,
            user_id,
            session_id,
            section_id,
            page_id,
            content_element_id,
            video_url,
            video_title,
            verb,
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
                format_sql_value(event_data['timestamp']),
                format_sql_value(event_data['user_id']),
                format_sql_value(event_data['session_id']),
                str(event_data['section_id']),
                str(event_data['page_id']),
                format_sql_value(event_data['content_element_id']),
                format_sql_value(event_data['video_url']),
                format_sql_value(event_data['video_title']),
                format_sql_value(event_data['verb']),
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
        page_id = extensions.get('http://oli.cmu.edu/extensions/page_id', 0)
        session_id = extensions.get('http://oli.cmu.edu/extensions/session_id', '')

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

        # Extract verb
        verb = safe_get_nested(event, 'verb.id', '')

        return {
            'event_id': event_id,
            'timestamp': timestamp,
            'user_id': user_id,
            'session_id': session_id,
            'section_id': int(section_id) if section_id else 0,
            'page_id': int(page_id) if page_id else 0,
            'content_element_id': content_element_id,
            'video_url': video_url,
            'video_title': video_title,
            'verb': verb,
            'video_time': float(video_time) if video_time is not None else None,
            'video_length': float(video_length) if video_length is not None else None,
            'video_progress': float(video_progress) if video_progress is not None else None,
            'video_played_segments': video_played_segments,
            'video_play_time': float(video_play_time) if video_play_time is not None else None,
            'video_seek_from': float(video_seek_from) if video_seek_from is not None else None,
            'video_seek_to': float(video_seek_to) if video_seek_to is not None else None
        }

    def get_section_event_count(self, section_id: int) -> int:
        """Get the count of events for a specific section"""
        table_name = self.get_video_events_table()
        query = f"SELECT COUNT(*) FROM {table_name} WHERE section_id = {section_id}"

        try:
            response = self._execute_query(query)
            count = int(response.text.strip())
            return count
        except Exception as e:
            logger.error(f"Failed to get section event count: {str(e)}")
            return 0

    def delete_section_events(self, section_id: int, before_timestamp: Optional[str] = None) -> int:
        """Delete events for a specific section, optionally before a timestamp"""
        table_name = self.get_video_events_table()

        where_clause = f"section_id = {section_id}"
        if before_timestamp:
            where_clause += f" AND timestamp < '{before_timestamp}'"

        query = f"ALTER TABLE {table_name} DELETE WHERE {where_clause}"

        try:
            self._execute_query(query)
            logger.info(f"Deleted events for section {section_id}")
            return 1  # ClickHouse ALTER DELETE doesn't return affected rows immediately
        except Exception as e:
            logger.error(f"Failed to delete section events: {str(e)}")
            return 0
