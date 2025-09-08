"""
Unified AWS Lambda function for XAPI ETL processing

This function handles both:
1. Event processing: Individual JSONL files from S3 (triggered by S3 events)
2. Bulk processing: Historical data processing (triggered manually)

The mode is determined by the event payload structure.
"""
import json
import logging
import boto3
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta, timezone
import sys
import os

# Add parent directory to path to import common modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common import (
    parse_s3_event,
    is_video_event,
    is_activity_attempt_event,
    is_page_attempt_event,
    is_page_viewed_event,
    is_part_attempt_event,
    extract_section_id_from_s3_key,
    get_config
)
from clickhouse_client import ClickHouseClient

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler that routes to event or bulk processing based on input

    Event Processing (S3 trigger):
    {
        "Records": [...] or "source": "aws.s3" or "bucket"/"key" fields
    }

    Bulk Processing (manual trigger):
    {
        "mode": "bulk",
        "section_id": "123",
        "start_date": "2024-01-01",
        "end_date": "2024-12-31",
        ...
    }

    Health Check:
    {
        "health_check": true
    }
    """
    logger.info(f"Processing event: {json.dumps(event)}")

    try:
        # Health check
        if event.get('health_check'):
            return health_check()

        # Determine processing mode
        if is_bulk_processing_event(event):
            logger.info("Routing to bulk processing mode")
            return handle_bulk_processing(event, context)
        else:
            logger.info("Routing to event processing mode")
            return handle_event_processing(event, context)

    except Exception as e:
        logger.error(f"Error in lambda handler: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def is_bulk_processing_event(event: Dict[str, Any]) -> bool:
    """Determine if this is a bulk processing request"""
    # Explicit bulk mode
    if event.get('mode') == 'bulk':
        return True

    # Has bulk processing parameters but no S3 event structure
    bulk_params = ['section_id', 'start_date', 'end_date', 's3_prefix', 'dry_run', 'force_reprocess']
    has_bulk_params = any(param in event for param in bulk_params)
    has_s3_structure = parse_s3_event(event) is not None

    return has_bulk_params and not has_s3_structure

def handle_event_processing(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handle single file processing (triggered by S3 events)"""
    try:
        # Parse S3 information from the event
        s3_info = parse_s3_event(event)
        if not s3_info:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid S3 event format'})
            }

        bucket = s3_info['bucket']
        key = s3_info['key']

        logger.info(f"Processing file s3://{bucket}/{key}")

        # Validate file type
        if not key.endswith('.jsonl'):
            logger.warning(f"Skipping non-JSONL file: {key}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Skipped non-JSONL file', 'file': key})
            }

        # Extract section ID from the S3 key
        section_id = extract_section_id_from_s3_key(key)
        if not section_id:
            logger.warning(f"Could not extract section_id from S3 key: {key}")

        # Check if this is a test mode invocation (from LambdaUploader)
        test_body = event.get('_test_body')
        test_mode = event.get('_test_mode', False)

        if test_mode and test_body:
            logger.info("Processing in test mode with provided body")
            result = process_single_file(bucket, key, test_body)
        else:
            # Use ClickHouse S3 integration for single file processing
            logger.info("Processing single file using ClickHouse S3 integration")
            clickhouse_client = ClickHouseClient()
            result = process_files_s3_integration(
                clickhouse_client, bucket, [key], section_id, False
            )

        # Add metadata to result
        result['section_id'] = section_id
        result['s3_key'] = key
        result['s3_bucket'] = bucket
        result['processing_mode'] = 'event'

        # For single file processing, adjust the result format
        if 'total_events_processed' in result:
            result['events_processed'] = result['total_events_processed']
            result['video_events_processed'] = result['total_video_events_processed']
            result['activity_attempt_events_processed'] = result['total_activity_attempt_events_processed']
            result['page_attempt_events_processed'] = result['total_page_attempt_events_processed']
            result['page_viewed_events_processed'] = result['total_page_viewed_events_processed']
            result['part_attempt_events_processed'] = result['total_part_attempt_events_processed']

        logger.info(f"Successfully processed {result.get('events_processed', 0)} events from {key}")

        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }

    except Exception as e:
        logger.error(f"Error in event processing: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e), 'processing_mode': 'event'})
        }

def handle_bulk_processing(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handle bulk processing of historical data"""
    try:
        # Extract parameters from event
        section_id = event.get('section_id')
        start_date = event.get('start_date')
        end_date = event.get('end_date')
        s3_bucket = event.get('s3_bucket')
        s3_prefix = event.get('s3_prefix', 'section/')
        force_reprocess = event.get('force_reprocess', False)
        dry_run = event.get('dry_run', False)

        logger.info(f"Starting bulk processing: section_id={section_id}, start_date={start_date}, end_date={end_date}")

        # Get default bucket if not specified
        if not s3_bucket:
            config = get_config()
            s3_bucket = os.getenv('S3_XAPI_BUCKET_NAME')
            if not s3_bucket:
                raise ValueError("S3_XAPI_BUCKET_NAME environment variable not set and no bucket specified")

        # Build S3 prefix based on parameters
        search_prefix = build_search_prefix(s3_prefix, section_id)

        logger.info(f"Searching for files in s3://{s3_bucket}/{search_prefix}")

        # Find files to process
        files_to_process = find_files_to_process(
            s3_bucket,
            search_prefix,
            start_date,
            end_date
        )

        logger.info(f"Found {len(files_to_process)} files to process")

        if dry_run:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Dry run completed',
                    'files_found': len(files_to_process),
                    'files': files_to_process[:10],  # Show first 10 files
                    'total_files': len(files_to_process),
                    'processing_mode': 'bulk'
                })
            }

        # Initialize ClickHouse client
        clickhouse_client = ClickHouseClient()

        # Process files
        result = process_files_bulk(
            clickhouse_client,
            s3_bucket,
            files_to_process,
            section_id,
            force_reprocess
        )

        result['processing_mode'] = 'bulk'
        logger.info(f"Bulk processing completed: {result}")

        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }

    except Exception as e:
        logger.error(f"Error in bulk processing: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e), 'processing_mode': 'bulk'})
        }

def process_single_file(bucket: str, key: str, test_body: Optional[str] = None) -> Dict[str, Any]:
    """Download and process a JSONL file from S3 or use provided test body"""
    try:
        if test_body:
            logger.info(f"Using provided test body for {key}")
            content = test_body
        else:
            logger.info(f"Downloading s3://{bucket}/{key}")
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')

        # Parse JSONL content
        events = []
        video_events = []
        activity_attempt_events = []
        page_attempt_events = []
        page_viewed_events = []
        part_attempt_events = []
        invalid_lines = 0

        for line_num, line in enumerate(content.strip().split('\n'), 1):
            if not line.strip():
                continue

            try:
                event_data = json.loads(line)
                events.append(event_data)

                # Categorize events by type
                if is_video_event(event_data):
                    video_events.append(event_data)
                elif is_activity_attempt_event(event_data):
                    activity_attempt_events.append(event_data)
                elif is_page_attempt_event(event_data):
                    page_attempt_events.append(event_data)
                elif is_page_viewed_event(event_data):
                    page_viewed_events.append(event_data)
                elif is_part_attempt_event(event_data):
                    part_attempt_events.append(event_data)

            except json.JSONDecodeError as e:
                logger.warning(f"Invalid JSON on line {line_num}: {str(e)}")
                invalid_lines += 1

        logger.info(f"Parsed {len(events)} total events: {len(video_events)} video, "
                   f"{len(activity_attempt_events)} activity attempts, "
                   f"{len(page_attempt_events)} page attempts, "
                   f"{len(page_viewed_events)} page views, "
                   f"{len(part_attempt_events)} part attempts, "
                   f"{invalid_lines} invalid lines")

        # Initialize ClickHouse client and process events
        clickhouse_client = ClickHouseClient()

        # Insert events by type
        video_events_inserted = 0
        activity_attempt_events_inserted = 0
        page_attempt_events_inserted = 0
        page_viewed_events_inserted = 0
        part_attempt_events_inserted = 0

        if video_events:
            video_events_inserted = clickhouse_client.insert_video_events(video_events)

        if activity_attempt_events:
            activity_attempt_events_inserted = clickhouse_client.insert_activity_attempt_events(activity_attempt_events)

        if page_attempt_events:
            page_attempt_events_inserted = clickhouse_client.insert_page_attempt_events(page_attempt_events)

        if page_viewed_events:
            page_viewed_events_inserted = clickhouse_client.insert_page_viewed_events(page_viewed_events)

        if part_attempt_events:
            part_attempt_events_inserted = clickhouse_client.insert_part_attempt_events(part_attempt_events)

        return {
            'events_processed': len(events),
            'video_events_processed': video_events_inserted,
            'activity_attempt_events_processed': activity_attempt_events_inserted,
            'page_attempt_events_processed': page_attempt_events_inserted,
            'page_viewed_events_processed': page_viewed_events_inserted,
            'part_attempt_events_processed': part_attempt_events_inserted,
            'invalid_lines': invalid_lines,
            'file_size_bytes': len(content),
            'success': True
        }

    except Exception as e:
        logger.error(f"Error processing file {bucket}/{key}: {str(e)}")
        raise

def build_search_prefix(base_prefix: str, section_id: Optional[str]) -> str:
    """Build S3 search prefix based on parameters"""
    if section_id:
        return f"{base_prefix.rstrip('/')}/{section_id}/"
    return base_prefix

def find_files_to_process(
    bucket: str,
    prefix: str,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
) -> List[str]:
    """Find JSONL files in S3 based on criteria"""
    files = []

    try:
        paginator = s3_client.get_paginator('list_objects_v2')
        page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)

        for page in page_iterator:
            if 'Contents' not in page:
                continue

            for obj in page['Contents']:
                key = obj['Key']

                if not key.endswith('.jsonl'):
                    continue

                if start_date or end_date:
                    if not meets_date_criteria(key, obj['LastModified'], start_date, end_date):
                        continue

                files.append(key)

        return sorted(files)

    except Exception as e:
        logger.error(f"Error finding files in S3: {str(e)}")
        raise

def meets_date_criteria(
    key: str,
    last_modified: datetime,
    start_date: Optional[str],
    end_date: Optional[str]
) -> bool:
    """Check if a file meets the date criteria"""
    try:
        # Try to extract date from filename first
        filename = key.split('/')[-1]
        if '_' in filename:
            timestamp_part = filename.split('_')[0]
            try:
                file_date = datetime.fromisoformat(timestamp_part.replace('Z', '+00:00'))
            except Exception:
                file_date = last_modified
        else:
            file_date = last_modified

        # Ensure all datetimes are offset-naive in UTC
        if file_date.tzinfo is not None:
            file_date = file_date.astimezone(timezone.utc).replace(tzinfo=None)
        if last_modified.tzinfo is not None:
            last_modified = last_modified.astimezone(timezone.utc).replace(tzinfo=None)

        # Apply date filters
        if start_date:
            start_dt = datetime.strptime(start_date, '%Y-%m-%d')
            if file_date < start_dt:
                return False

        if end_date:
            end_dt = datetime.strptime(end_date, '%Y-%m-%d') + timedelta(days=1)
            if file_date >= end_dt:
                return False

        return True

    except Exception as e:
        logger.warning(f"Error checking date criteria for {key}: {str(e)}")
        return True

def process_files_bulk(
    clickhouse_client: ClickHouseClient,
    bucket: str,
    files: List[str],
    section_id: Optional[str] = None,
    force_reprocess: bool = False
) -> Dict[str, Any]:
    """
    Process multiple files using ClickHouse S3 integration for optimal performance.
    All processing is now handled by ClickHouse's native S3 capabilities.
    """
    logger.info(f"Processing {len(files)} files using ClickHouse S3 integration")

    try:
        return process_files_s3_integration(
            clickhouse_client, bucket, files, section_id, force_reprocess
        )
    except Exception as e:
        logger.error(f"S3 integration processing failed: {str(e)}")
        raise

def process_files_s3_integration(
    clickhouse_client: ClickHouseClient,
    bucket: str,
    files: List[str],
    section_id: Optional[str] = None,
    force_reprocess: bool = False
) -> Dict[str, Any]:
    """Process multiple files using ClickHouse S3 integration for efficiency"""
    try:
        # Check if we should skip processing
        if not force_reprocess and section_id:
            existing_count = clickhouse_client.get_section_event_count(int(section_id))
            if existing_count > 0:
                logger.info(f"Skipping S3 bulk processing - section {section_id} already has {existing_count} events")
                return {
                    'total_files_found': len(files),
                    'processed_files': 0,
                    'failed_files': 0,
                    'skipped_files': len(files),
                    'total_events_processed': 0,
                    'total_video_events_processed': 0,
                    'total_activity_attempt_events_processed': 0,
                    'total_page_attempt_events_processed': 0,
                    'total_page_viewed_events_processed': 0,
                    'total_part_attempt_events_processed': 0,
                    'section_id': section_id,
                    'success': True,
                    'processing_method': 's3_integration'
                }

        # Convert file keys to full S3 paths
        s3_paths = [f"s3://{bucket}/{key}" for key in files]

        # Use ClickHouse S3 integration to process all files at once
        results = clickhouse_client.bulk_insert_from_s3(s3_paths, int(section_id) if section_id else None)

        return {
            'total_files_found': len(files),
            'processed_files': len(files),
            'failed_files': 0,
            'skipped_files': 0,
            'total_events_processed': results['total_events_processed'],
            'total_video_events_processed': results['video_events_processed'],
            'total_activity_attempt_events_processed': results['activity_attempt_events_processed'],
            'total_page_attempt_events_processed': results['page_attempt_events_processed'],
            'total_page_viewed_events_processed': results['page_viewed_events_processed'],
            'total_part_attempt_events_processed': results['part_attempt_events_processed'],
            'section_id': section_id,
            'success': True,
            'processing_method': 's3_integration'
        }

    except Exception as e:
        logger.error(f"S3 integration processing failed: {str(e)}")
        raise

def health_check() -> Dict[str, Any]:
    """Health check endpoint"""
    try:
        clickhouse_client = ClickHouseClient()
        is_healthy = clickhouse_client.health_check()

        return {
            'statusCode': 200 if is_healthy else 500,
            'body': json.dumps({
                'clickhouse_healthy': is_healthy,
                'lambda_function': 'xapi-etl-processor',
                'modes': ['event', 'bulk'],
                'processing_method': 's3_integration',
                'description': 'All processing uses ClickHouse S3 integration for optimal performance',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'clickhouse_healthy': False,
                'lambda_function': 'xapi-etl-processor'
            })
        }

# Test function
if __name__ == "__main__":
    # Test event processing
    test_event_mode = {
        'bucket': 'test-bucket',
        'key': 'section/123/video/2024-01-01T12-00-00.000Z_test-bundle.jsonl'
    }

    # Test bulk processing
    test_bulk_mode = {
        'mode': 'bulk',
        'section_id': '123',
        'start_date': '2024-01-01',
        'end_date': '2024-12-31',
        'dry_run': True
    }

    print("Event mode test:")
    print(json.dumps(lambda_handler(test_event_mode, None), indent=2))

    print("\nBulk mode test:")
    print(json.dumps(lambda_handler(test_bulk_mode, None), indent=2))
