# XAPI ETL Unified System Tests

## Overview

This test suite provides comprehensive production-level unit tests for the unified XAPI ETL system that uses a single `raw_events` table instead of separate tables for each event type.

## Test Coverage

### 🗃️ Unified ClickHouse Client (`test_clickhouse_client.py`)

- **Event Type Determination**: Tests mapping of verb/object combinations to event types
- **Event Transformation**: Tests conversion of xAPI events to unified table format
- **Database Operations**: Tests insertion, querying, and deletion operations
- **Error Handling**: Tests malformed data and connection issues
- **Performance**: Tests bulk processing capabilities

### ⚡ Lambda Function (`test_lambda_function.py`)

- **Event Processing**: Tests S3 trigger handling and event processing
- **Error Scenarios**: Tests health check failures and processing errors
- **Multi-file Processing**: Tests handling of multiple S3 files
- **Response Format**: Tests Lambda response structure and status codes

### 🔗 Integration Tests (`test_integration.py`)

- **End-to-End Processing**: Tests complete pipeline from raw events to database
- **S3 Integration**: Tests S3 bulk processing with unified table approach
- **Event Type Mapping**: Tests all supported event type classifications
- **Performance Characteristics**: Tests processing speed and efficiency

## Running Tests

### Quick Start

```bash
# From the project root directory
cd /Users/eliknebel/Developer/oli-torus/cloud/xapi-etl-processor

# Option 1: Use the simple test script
python test.py

# Option 2: Use unittest discovery directly
python -m unittest discover tests -v

# Option 3: Use Makefile (if you prefer)
make test

# Or from the tests directory
cd tests
python -m unittest discover . -v
```

### Individual Test Suites

```bash
# ClickHouse client tests only
python -m unittest tests.test_clickhouse_client -v
# or: make test-clickhouse

# Lambda function tests only
python -m unittest tests.test_lambda_function -v
# or: make test-lambda

# Integration tests only
python -m unittest tests.test_integration -v
# or: make test-integration
```

### Specific Test Methods

```bash
# Run a specific test class
python -m unittest tests.test_clickhouse_client.TestClickHouseClientUnified -v

# Run a specific test method
python -m unittest tests.test_clickhouse_client.TestClickHouseClientUnified.test_transform_raw_event_video -v
```

## Test Configuration

### Unit Tests (No Configuration Required)

- Use mocked dependencies
- Test core logic and transformations
- Run without external services

### Integration Tests (Optional)

Set these environment variables to run real ClickHouse integration tests:

```bash
export CLICKHOUSE_URL="http://your-clickhouse:8123"
export CLICKHOUSE_USERNAME="your_username"
export CLICKHOUSE_PASSWORD="your_password"
```

**Note**: Integration tests are automatically skipped if these variables are not set.

## Test Results

Running the tests will output:

- **Console Output**: Detailed test results with pass/fail status
- **Test Summary**: Count of passed, failed, and skipped tests
- **Error Details**: Full stack traces for any failures

Example output:

```
test_transform_raw_event_video (test_clickhouse_client.TestClickHouseClientUnified) ... ok
test_lambda_handler_success (test_lambda_function.TestLambdaFunctionUnified) ... ok

----------------------------------------------------------------------
Ran 23 tests in 0.015s

OK
```

## Key Benefits Validated

### 🎯 Unified Table Approach

- ✅ Single `raw_events` table handles all event types
- ✅ `event_type` column properly differentiates events
- ✅ Nullable columns accommodate different event schemas
- ✅ No JOINs required for cross-event-type queries

### 🚀 Performance Improvements

- ✅ Simplified ETL pipeline reduces complexity
- ✅ Single INSERT statement for all event types
- ✅ Better ClickHouse optimization with unified schema
- ✅ Faster bulk S3 processing

### 🔧 Maintainability

- ✅ Single client class instead of multiple event handlers
- ✅ Unified transformation logic
- ✅ Simplified migration and schema management
- ✅ Easier to add new event types

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure you're running from the correct directory
2. **Configuration Errors**: Check that `common.py` and config files are accessible
3. **Mock Failures**: Verify mock patches match actual module structure

### Verbose Output

```bash
python -m unittest discover tests -v
```

## Continuous Integration

The test suite works with standard Python testing tools:

- **Standard unittest**: Uses Python's built-in unittest framework
- **Exit Codes**: Returns appropriate exit codes for CI systems
- **Verbose Output**: Use `-v` flag for detailed test output
- **Test Discovery**: Automatic test discovery with `python -m unittest discover`

Example CI configuration:

```yaml
# GitHub Actions example
- name: Run tests
  run: |
    cd cloud/xapi-etl-processor
    python -m unittest discover tests -v
```

## Development

### Adding New Tests

1. **Unit Tests**: Add to appropriate test class in existing files
2. **Integration Tests**: Add to `test_integration.py` for end-to-end scenarios
3. **Performance Tests**: Include timing assertions for critical paths

### Test Data

- Use the provided sample events as templates
- Ensure test data covers all supported event types
- Include edge cases and malformed data scenarios

## Production Deployment

Before deploying the unified system:

1. ✅ Run full test suite: `python -m unittest discover tests -v`
2. ✅ Verify all tests pass
3. ✅ Test with representative production data (staging environment)
4. ✅ Validate performance with expected data volumes

---

🎉 **The unified table approach significantly simplifies the XAPI ETL system while maintaining all functionality and improving performance!**
