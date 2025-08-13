#!/bin/bash

# XAPI ETL Lambda Deployment Script
# This script creates deployment packages for the unified XAPI ETL processor

set -e

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LAMBDA_DIR="$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/build"
PACKAGE_NAME="xapi-etl-processor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command_exists python3; then
        error "Python 3 is required but not installed"
        exit 1
    fi

    if ! command_exists pip3; then
        error "pip3 is required but not installed"
        exit 1
    fi

    if ! command_exists zip; then
        error "zip is required but not installed"
        exit 1
    fi

    # Check if Lambda directory exists
    if [ ! -d "$LAMBDA_DIR" ]; then
        error "Lambda directory not found: $LAMBDA_DIR"
        exit 1
    fi

    # Check if required files exist
    required_files=("lambda_function.py" "common.py" "clickhouse_client.py" "requirements.txt")
    for file in "${required_files[@]}"; do
        if [ ! -f "$LAMBDA_DIR/$file" ]; then
            error "Required file not found: $LAMBDA_DIR/$file"
            exit 1
        fi
    done

    log "Prerequisites check passed"
}

# Create build directory
setup_build_directory() {
    log "Setting up build directory..."

    # Clean existing build directory
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi

    mkdir -p "$BUILD_DIR"
    log "Build directory created: $BUILD_DIR"
}

# Install dependencies
install_dependencies() {
    log "Installing Python dependencies..."

    # Create temporary requirements file to avoid installing dev dependencies
    cat > "$BUILD_DIR/requirements.txt" << EOF
boto3
requests
clickhouse-driver
EOF

    # Install dependencies to the build directory
    pip3 install -r "$BUILD_DIR/requirements.txt" -t "$BUILD_DIR" --no-cache-dir

    # Remove unnecessary files to reduce package size
    find "$BUILD_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$BUILD_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
    find "$BUILD_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
    find "$BUILD_DIR" -name "*.pyc" -delete 2>/dev/null || true

    log "Dependencies installed successfully"
}

# Copy Lambda source code
copy_source_code() {
    log "Copying Lambda source code..."

    # Copy Lambda function files
    cp "$LAMBDA_DIR/lambda_function.py" "$BUILD_DIR/"
    cp "$LAMBDA_DIR/common.py" "$BUILD_DIR/"
    cp "$LAMBDA_DIR/clickhouse_client.py" "$BUILD_DIR/"

    log "Source code copied successfully"
}

# Create deployment package
create_deployment_package() {
    log "Creating deployment package..."

    cd "$BUILD_DIR"

    # Create the ZIP file
    zip_file="$SCRIPT_DIR/${PACKAGE_NAME}.zip"
    if [ -f "$zip_file" ]; then
        rm "$zip_file"
    fi

    zip -r "$zip_file" . -q

    cd "$SCRIPT_DIR"

    # Get package size
    package_size=$(du -h "${zip_file}" | cut -f1)

    log "Deployment package created: ${zip_file} (${package_size})"

    # Warn if package is large
    package_size_bytes=$(stat -f%z "${zip_file}" 2>/dev/null || stat -c%s "${zip_file}" 2>/dev/null)
    if [ "$package_size_bytes" -gt 52428800 ]; then  # 50MB
        warn "Package size is large (${package_size}). Consider optimizing dependencies."
    fi
}

# Validate package
validate_package() {
    log "Validating deployment package..."

    zip_file="$SCRIPT_DIR/${PACKAGE_NAME}.zip"

    # Check if package exists
    if [ ! -f "$zip_file" ]; then
        error "Deployment package not found: $zip_file"
        return 1
    fi

    # List contents to verify
    info "Package contents:"
    unzip -l "$zip_file" | head -20

    # Check for required files
    required_files=("lambda_function.py" "common.py" "clickhouse_client.py")
    for file in "${required_files[@]}"; do
        if ! unzip -l "$zip_file" | grep -q "$file"; then
            error "Required file missing from package: $file"
            return 1
        fi
    done

    log "Package validation passed"
}

# Test Lambda function locally (optional)
test_locally() {
    if [ "$1" = "--test" ]; then
        log "Testing Lambda function locally..."

        cd "$BUILD_DIR"

        # Create test event files
        cat > test_event_mode.json << EOF
{
    "bucket": "test-bucket",
    "key": "section/123/video/2024-01-01T12-00-00.000Z_test.jsonl"
}
EOF

        cat > test_bulk_mode.json << EOF
{
    "mode": "bulk",
    "section_id": "123",
    "start_date": "2024-01-01",
    "end_date": "2024-12-31",
    "dry_run": true
}
EOF

        cat > test_health_check.json << EOF
{
    "health_check": true
}
EOF

        # Test syntax
        python3 -m py_compile lambda_function.py
        log "Lambda function syntax is valid"

        cd "$SCRIPT_DIR"
    fi
}

# Deploy to AWS (optional)
deploy_to_aws() {
    if [ "$1" = "--deploy" ]; then
        log "Deploying to AWS Lambda..."

        # Check if AWS CLI is available
        if ! command_exists aws; then
            error "AWS CLI is required for deployment but not installed"
            return 1
        fi

        # Check if function name is provided
        if [ -z "$2" ]; then
            error "Function name is required for deployment"
            echo "Usage: $0 --deploy FUNCTION_NAME"
            return 1
        fi

        function_name="$2"
        zip_file="$SCRIPT_DIR/${PACKAGE_NAME}.zip"

        # Update Lambda function
        aws lambda update-function-code \
            --function-name "$function_name" \
            --zip-file "fileb://$zip_file"

        log "Deployed to Lambda function: $function_name"
    fi
}

# Display help
show_help() {
    echo "XAPI ETL Lambda Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --test         Test the Lambda function locally"
    echo "  --deploy NAME  Deploy to AWS Lambda function NAME"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build deployment package only"
    echo "  $0 --test                            # Build and test locally"
    echo "  $0 --deploy xapi-etl-processor       # Build and deploy to AWS"
    echo "  $0 --test --deploy xapi-etl-processor # Build, test, and deploy"
}

# Main execution
main() {
    log "Starting XAPI ETL Lambda deployment"

    # Parse arguments
    TEST_FLAG=""
    DEPLOY_FLAG=""
    FUNCTION_NAME=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                TEST_FLAG="--test"
                shift
                ;;
            --deploy)
                DEPLOY_FLAG="--deploy"
                FUNCTION_NAME="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Execute deployment steps
    check_prerequisites
    setup_build_directory
    install_dependencies
    copy_source_code
    create_deployment_package
    validate_package
    test_locally "$TEST_FLAG"
    deploy_to_aws "$DEPLOY_FLAG" "$FUNCTION_NAME"

    # Clean up build directory
    rm -rf "$BUILD_DIR"

    log "Deployment completed successfully!"
    info "Deployment package: $SCRIPT_DIR/${PACKAGE_NAME}.zip"

    if [ -n "$DEPLOY_FLAG" ] && [ -n "$FUNCTION_NAME" ]; then
        info "Deployed to Lambda function: $FUNCTION_NAME"
    fi
}

# Run main function with all arguments
main "$@"
