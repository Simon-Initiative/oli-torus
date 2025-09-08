"""
Tests package for XAPI ETL Processor

This package contains unit tests for the unified ClickHouse ETL system.

Usage:
    # Run all tests
    python -m unittest discover -s tests -p "test_*.py" -v

    # Run specific test module
    python -m unittest tests.clickhouse_client -v
    python -m unittest tests.test_lambda_function -v
    python -m unittest tests.test_integration -v

    # Run from project root
    cd /path/to/oli-torus/cloud/xapi-etl-processor
    python -m unittest discover tests -v
"""
