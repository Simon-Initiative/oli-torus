"""
Simplified AWS Lambda function for XAPI ETL processing using unified raw_events table

This function handles both:
1. Event processing: Individual JSONL files from S3 (triggered by S3 events)
2. Bulk processing: Historical data processing (triggered manually)

The mode is determined by the event payload structure.
All events are now stored in a single unified raw_events table for improved performance.
"""
import sys
import os
import json
import logging
import boto3
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta, timezone

# Add parent directory to path to import common modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common import (
    parse_s3_event,
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
        "section_ids": [123],  # Single section as list
        "start_date": "2024-01-01",
        "end_date": "2024-12-31",
        ...
    }

    Multi-Section Bulk Processing:
    {
        "mode": "bulk",
        "section_ids": [123, 124, 125],  # Multiple sections
        "batch_size": 5,
        "force_reprocess": false,
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
    bulk_params = ['section_ids', 'start_date', 'end_date', 's3_prefix', 'dry_run', 'force_reprocess']
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
            result = process_single_file_s3_integration(bucket, key, section_id)

        # Add metadata to result
        result['section_id'] = section_id
        result['s3_key'] = key
        result['s3_bucket'] = bucket
        result['processing_mode'] = 'event'
        result['processing_method'] = 'unified_table'

        logger.info(f"Successfully processed {result.get('total_events_processed', 0)} events from {key}")

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
    """Handle bulk processing of historical data - unified approach for single or multiple sections"""
    try:
        # Extract section IDs - required parameter
        section_ids = event.get('section_ids', [])

        if not section_ids:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'section_ids is required for bulk processing'})
            }

        # Convert all to strings for consistency
        section_ids = [str(sid) for sid in section_ids]

        # Extract other parameters
        start_date = event.get('start_date')
        end_date = event.get('end_date')
        s3_bucket = event.get('s3_bucket')
        s3_prefix = event.get('s3_prefix', 'section/')
        force_reprocess = event.get('force_reprocess', False)
        batch_size = event.get('batch_size', 5)
        dry_run = event.get('dry_run', False)

        logger.info(f"Starting bulk processing: section_ids={section_ids}, batch_size={batch_size}")

        # Get default bucket if not specified
        if not s3_bucket:
            config = get_config()
            s3_bucket = config.get('aws', {}).get('default_bucket', 'torus-xapi-dev')

        # Initialize ClickHouse client
        clickhouse_client = ClickHouseClient()

        # Track results
        successful_sections = []
        failed_sections = []
        section_results = {}

        # Process sections in batches
        for i in range(0, len(section_ids), batch_size):
            batch = section_ids[i:i+batch_size]
            batch_num = (i // batch_size) + 1
            total_batches = (len(section_ids) + batch_size - 1) // batch_size

            logger.info(f"Processing batch {batch_num}/{total_batches}: {batch}")

            for section_id in batch:
                try:
                    logger.info(f"Processing section {section_id}...")

                    # Build S3 prefix for this section
                    search_prefix = build_search_prefix(s3_prefix, section_id)

                    # Find files for this section
                    files_to_process = find_files_to_process(
                        s3_bucket,
                        search_prefix,
                        start_date,
                        end_date
                    )

                    if not files_to_process:
                        logger.warning(f"No files found for section {section_id}")
                        section_results[section_id] = {
                            'status': 'skipped',
                            'reason': 'no_files_found',
                            'files_found': 0
                        }
                        continue

                    if dry_run:
                        section_results[section_id] = {
                            'status': 'dry_run',
                            'files_found': len(files_to_process),
                            'files': files_to_process[:5]  # Show first 5 files
                        }
                        continue

                    # Process files for this section
                    result = process_files_bulk(
                        clickhouse_client,
                        s3_bucket,
                        files_to_process,
                        section_id,
                        force_reprocess
                    )

                    if result.get('success', True):
                        successful_sections.append(section_id)
                        section_results[section_id] = {
                            'status': 'success',
                            'total_events_processed': result.get('total_events_processed', 0),
                            'files_processed': result.get('processed_files', 0),
                            'processing_method': result.get('processing_method', 'unknown'),
                            'existing_events_count': result.get('existing_events_count', 0),
                            'message': result.get('message', '')
                        }
                        events_processed = result.get('total_events_processed', 0)
                        logger.info(f"Successfully processed section {section_id}: {events_processed} events")
                    else:
                        failed_sections.append(section_id)
                        section_results[section_id] = {
                            'status': 'failed',
                            'error': result.get('error', 'Unknown error')
                        }

                except Exception as e:
                    logger.error(f"Error processing section {section_id}: {str(e)}")
                    failed_sections.append(section_id)
                    section_results[section_id] = {
                        'status': 'failed',
                        'error': str(e)
                    }

        # Calculate totals
        total_events_processed = sum(
            result.get('total_events_processed', 0)
            for result in section_results.values()
            if isinstance(result.get('total_events_processed'), int)
        )

        # Determine processing mode based on number of sections
        processing_mode = 'bulk_single_section' if len(section_ids) == 1 else 'bulk_multiple_sections'

        summary_result = {
            'processing_mode': processing_mode,
            'processing_method': 'unified_table',
            'total_sections_requested': len(section_ids),
            'successful_sections': len(successful_sections),
            'failed_sections': len(failed_sections),
            'total_events_processed': total_events_processed,
            'section_results': section_results,
            'dry_run': dry_run
        }

        if successful_sections:
            summary_result['successful_section_ids'] = successful_sections
        if failed_sections:
            summary_result['failed_section_ids'] = failed_sections

        # For single section, also include direct results at top level for convenience
        if len(section_ids) == 1:
            section_id = section_ids[0]
            section_result = section_results.get(section_id, {})
            summary_result.update({
                'section_id': section_id,
                'files_found': len(find_files_to_process(s3_bucket, build_search_prefix(s3_prefix, section_id), start_date, end_date)) if not dry_run else section_result.get('files_found', 0),
                'processed_files': section_result.get('files_processed', 0),
                'skipped_files': section_result.get('files_found', 0) - section_result.get('files_processed', 0) if section_result.get('status') == 'success' else 0,
                'existing_events_count': section_result.get('existing_events_count', 0),
                'message': section_result.get('message', '')
            })

        logger.info(f"Bulk processing completed: {summary_result}")

        return {
            'statusCode': 200,
            'body': json.dumps(summary_result)
        }

    except Exception as e:
        logger.error(f"Error in bulk processing: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e), 'processing_mode': 'bulk'})
        }

def process_single_file_s3_integration(bucket: str, key: str, section_id: Optional[str] = None) -> Dict[str, Any]:
    """Process a single file using ClickHouse S3 integration"""
    try:
        s3_path = f"s3://{bucket}/{key}"

        # Initialize ClickHouse client
        clickhouse_client = ClickHouseClient()

        # Health check before processing
        if not clickhouse_client.health_check():
            raise Exception("ClickHouse health check failed")

        # Process the file using S3 integration
        section_id_int = int(section_id) if section_id else None
        result = clickhouse_client._process_single_s3_file_unified(s3_path, section_id_int)

        result['success'] = True
        result['processing_method'] = 'unified_s3_integration'

        return result

    except Exception as e:
        logger.error(f"Error processing file {bucket}/{key} with S3 integration: {str(e)}")
        raise

def process_single_file(bucket: str, key: str, test_body: Optional[str] = None) -> Dict[str, Any]:
    """Download and process a JSONL file from S3 or use provided test body"""
    try:
        if test_body:
            content = test_body
        else:
            # Download file from S3
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')

        # Parse JSONL content
        events = []
        invalid_lines = 0

        for line_num, line in enumerate(content.strip().split('\n'), 1):
            line = line.strip()
            if not line:
                continue
            try:
                event_data = json.loads(line)
                events.append(event_data)
            except json.JSONDecodeError as e:
                logger.warning(f"Invalid JSON on line {line_num}: {str(e)}")
                invalid_lines += 1

        logger.info(f"Parsed {len(events)} total events, {invalid_lines} invalid lines")

        # Initialize ClickHouse client and process events
        clickhouse_client = ClickHouseClient()

        # Insert all events into unified table
        events_inserted = 0
        if events:
            events_inserted = clickhouse_client.insert_raw_events(events)

        # Get counts by event type for reporting
        result = {
            'total_events_processed': events_inserted,
            'invalid_lines': invalid_lines,
            'file_size_bytes': len(content),
            'success': True,
            'processing_method': 'unified_table_direct'
        }

        # If we have a section ID, get breakdown by event type
        if events:
            section_id = events[0].get('context', {}).get('extensions', {}).get('http://oli.cmu.edu/extensions/section_id')
            if section_id:
                try:
                    counts_by_type = clickhouse_client.get_section_event_count_by_type(int(section_id))
                    result.update({
                        'video_events_processed': counts_by_type.get('video', 0),
                        'activity_attempt_events_processed': counts_by_type.get('activity_attempt', 0),
                        'page_attempt_events_processed': counts_by_type.get('page_attempt', 0),
                        'page_viewed_events_processed': counts_by_type.get('page_viewed', 0),
                        'part_attempt_events_processed': counts_by_type.get('part_attempt', 0),
                    })
                except Exception as e:
                    logger.warning(f"Could not get event counts by type: {str(e)}")

        return result

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
                last_modified = obj['LastModified']

                # Only process JSONL files
                if not key.endswith('.jsonl'):
                    continue

                # Check date criteria
                if meets_date_criteria(key, last_modified, start_date, end_date):
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
            date_part = filename.split('_')[0]
            try:
                file_date = datetime.fromisoformat(date_part.replace('Z', ''))
            except ValueError:
                file_date = last_modified
        else:
            file_date = last_modified

        # Ensure all datetimes are offset-naive in UTC
        if file_date.tzinfo is not None:
            file_date = file_date.replace(tzinfo=None)
        if last_modified.tzinfo is not None:
            last_modified = last_modified.replace(tzinfo=None)

        # Apply date filters
        if start_date:
            start_dt = datetime.fromisoformat(start_date)
            if file_date < start_dt:
                return False

        if end_date:
            end_dt = datetime.fromisoformat(end_date)
            if file_date > end_dt:
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
    All processing is now handled by ClickHouse's native S3 capabilities with unified table.
    """
    logger.info(f"Processing {len(files)} files using ClickHouse S3 integration with unified raw_events table")

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
    """Process multiple files using ClickHouse S3 integration with unified table"""
    try:
        # Check if we should skip processing
        if not force_reprocess and section_id:
            existing_count = clickhouse_client.get_section_event_count(int(section_id))
            if existing_count > 0:
                logger.info(f"Section {section_id} already has {existing_count} events. Use force_reprocess=True to reprocess.")
                return {
                    'total_files_found': len(files),
                    'processed_files': 0,
                    'failed_files': 0,
                    'skipped_files': len(files),
                    'total_events_processed': 0,
                    'existing_events_count': existing_count,
                    'section_id': section_id,
                    'success': True,
                    'processing_method': 'unified_s3_integration',
                    'message': 'Processing skipped - data already exists'
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
            'processing_method': 'unified_s3_integration'
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
                'processing_method': 'unified_s3_integration',
                'table_structure': 'unified_raw_events',
                'description': 'All events stored in single raw_events table for optimal performance',
                'capabilities': [
                    'Single file processing',
                    'Unified bulk processing (single or multiple sections)',
                    'Automatic batching for multiple sections'
                ],
                'bulk_parameters': {
                    'section_ids': 'List of section IDs for processing (required)',
                    'batch_size': 'Number of sections to process per batch (default: 5)',
                    'force_reprocess': 'Reprocess existing data (default: false)',
                    'dry_run': 'Preview files without processing (default: false)',
                    'start_date': 'Filter files by date (ISO format, optional)',
                    'end_date': 'Filter files by date (ISO format, optional)',
                    's3_bucket': 'S3 bucket name (optional, uses default)',
                    's3_prefix': 'S3 prefix for files (default: "section/")'
                },
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

    # Test single section bulk processing
    test_single_section = {
        'mode': 'bulk',
        'section_ids': [123],
        'dry_run': True
    }

    # Test multiple sections bulk processing
    test_multiple_sections = {
        'mode': 'bulk',
        'section_ids': [123, 124, 125],
        'batch_size': 2,
        'force_reprocess': False,
        'dry_run': True
    }

    print("Event mode test:")
    print(json.dumps(lambda_handler(test_event_mode, None), indent=2))

    print("\nSingle section bulk mode test:")
    print(json.dumps(lambda_handler(test_single_section, None), indent=2))

    print("\nMultiple sections bulk mode test:")
    print(json.dumps(lambda_handler(test_multiple_sections, None), indent=2))
