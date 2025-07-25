#!/bin/bash

# ClickHouse Migration Helper Script
# This script provides commands to manage ClickHouse migrations using dbmate

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env.clickhouse" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env.clickhouse" | xargs)
fi

# Default values
DATABASE_URL=${DATABASE_URL:-"clickhouse://default@localhost:8123/default"}
DBMATE_MIGRATIONS_DIR=${DBMATE_MIGRATIONS_DIR:-"priv/clickhouse/migrations"}

# Function to run dbmate with proper configuration
run_dbmate() {
    docker run --rm \
        --network oli-torus_default \
        -e DATABASE_URL="$DATABASE_URL" \
        -e DBMATE_MIGRATIONS_DIR="/db/migrations" \
        -e DBMATE_NO_DUMP_SCHEMA=true \
        -v "$PROJECT_ROOT/$DBMATE_MIGRATIONS_DIR:/db/migrations" \
        amacneil/dbmate:latest "$@"
}

# Function to check if ClickHouse is running
check_clickhouse() {
    echo "Checking ClickHouse connection..."
    if ! curl -s "http://localhost:8123/" > /dev/null; then
        echo "Error: ClickHouse is not running or not accessible"
        echo "Please start ClickHouse with: docker-compose up -d clickhouse"
        exit 1
    fi
    echo "ClickHouse is running ✓"
}

# Main command dispatcher
case "${1:-help}" in
    "up")
        echo "Running ClickHouse migrations..."
        check_clickhouse
        run_dbmate up
        echo "Migrations completed ✓"
        ;;

    "down")
        echo "Rolling back last ClickHouse migration..."
        check_clickhouse
        run_dbmate down
        echo "Rollback completed ✓"
        ;;

    "status")
        echo "Checking ClickHouse migration status..."
        check_clickhouse
        run_dbmate status
        ;;

    "new")
        if [ -z "$2" ]; then
            echo "Error: Migration name is required"
            echo "Usage: $0 new migration_name"
            exit 1
        fi
        echo "Creating new migration: $2"
        run_dbmate new "$2"
        echo "Migration file created ✓"
        ;;

    "drop")
        echo "Dropping ClickHouse database..."
        check_clickhouse
        run_dbmate drop
        echo "Database dropped ✓"
        ;;

    "create")
        echo "Creating ClickHouse database..."
        check_clickhouse
        run_dbmate create
        echo "Database created ✓"
        ;;

    "migrate-docker")
        echo "Running migrations using docker-compose..."
        docker-compose --profile migrate up clickhouse-migrate
        echo "Docker migrations completed ✓"
        ;;

    "help"|*)
        echo "ClickHouse Migration Helper"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  up              Run pending migrations"
        echo "  down            Rollback the last migration"
        echo "  status          Show migration status"
        echo "  new <name>      Create a new migration file"
        echo "  create          Create the database"
        echo "  drop            Drop the database"
        echo "  migrate-docker  Run migrations using docker-compose"
        echo "  help            Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 up"
        echo "  $0 new add_user_sessions_table"
        echo "  $0 status"
        ;;
esac
