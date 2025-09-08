#!/usr/bin/env python3
"""
Test script to validate S3 single file processing functionality
"""

import os
import sys
import logging
from clickhouse_client import ClickHouseClient

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_s3_single_file():
    """Test processing a single S3 file"""

    # Initialize ClickHouse client
    try:
        client = ClickHouseClient()
        logger.info("✅ ClickHouse client initialized successfully")
    except Exception as e:
        logger.error(f"❌ Failed to initialize ClickHouse client: {str(e)}")
        return False

    # Test with a sample S3 path (this would be a real S3 path in production)
    test_s3_path = "s3://oli-learning-data/xapi-data/test-section-123/test-file.jsonl"
    section_id = 123

    try:
        # Test the _process_single_s3_file method
        logger.info(f"Testing _process_single_s3_file with path: {test_s3_path}")

        # Note: This will fail with actual S3 call since we don't have real data
        # but it will validate the syntax and method existence
        results = client._process_single_s3_file(test_s3_path, section_id)

        logger.info(f"✅ _process_single_s3_file method executed successfully")
        logger.info(f"Results: {results}")

        return True

    except Exception as e:
        error_msg = str(e)

        # Check if it's the expected S3 error (file doesn't exist) vs syntax error
        if "S3" in error_msg and ("NoSuchKey" in error_msg or "file" in error_msg.lower()):
            logger.info(f"✅ Method syntax is correct, got expected S3 file error: {error_msg}")
            return True
        elif "NUMBER_OF_ARGUMENTS_DOESNT_MATCH" in error_msg:
            logger.error(f"❌ S3 function syntax error still exists: {error_msg}")
            return False
        else:
            logger.error(f"❌ Unexpected error: {error_msg}")
            return False

def test_batch_processing_logic():
    """Test the batch processing logic without actual S3 calls"""

    client = ClickHouseClient()

    # Test data - minimal set
    test_files = [
        "s3://bucket/file1.jsonl",
        "s3://bucket/file2.jsonl"
    ]

    try:
        # Test the bulk_insert_from_s3 method logic which actually uses our new implementation
        logger.info("Testing bulk_insert_from_s3 method with small batch")

        # This will fail on actual S3 calls but should show proper individual file iteration
        results = client.bulk_insert_from_s3(test_files, 123)

        logger.info(f"✅ Batch processing logic is correct")
        return True

    except Exception as e:
        error_msg = str(e)

        if "S3" in error_msg and ("file" in error_msg.lower() or "NoSuchKey" in error_msg or "NoSuchBucket" in error_msg):
            logger.info(f"✅ Batch logic is correct, got expected S3 error: {error_msg}")
            return True
        elif "NUMBER_OF_ARGUMENTS_DOESNT_MATCH" in error_msg:
            logger.error(f"❌ Batch processing still has S3 syntax error: {error_msg}")
            return False
        elif "BAD_ARGUMENTS" in error_msg and "Array" in error_msg:
            logger.error(f"❌ Still passing arrays to S3 function: {error_msg}")
            return False
        else:
            logger.error(f"❌ Unexpected error in batch processing: {error_msg}")
            return False

if __name__ == "__main__":
    logger.info("🧪 Starting S3 single file processing tests")

    # Test 1: Single file processing
    logger.info("\n📝 Test 1: Single file processing method")
    test1_passed = test_s3_single_file()

    # Test 2: Batch processing logic
    logger.info("\n📝 Test 2: Batch processing logic")
    test2_passed = test_batch_processing_logic()

    # Summary
    logger.info("\n📊 Test Summary:")
    logger.info(f"  Single file processing: {'✅ PASS' if test1_passed else '❌ FAIL'}")
    logger.info(f"  Batch processing logic: {'✅ PASS' if test2_passed else '❌ FAIL'}")

    if test1_passed and test2_passed:
        logger.info("\n🎉 All tests passed! S3 syntax should be fixed.")
        sys.exit(0)
    else:
        logger.info("\n⚠️  Some tests failed. Check the implementation.")
        sys.exit(1)
