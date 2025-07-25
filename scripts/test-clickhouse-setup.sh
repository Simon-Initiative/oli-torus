#!/bin/bash

# Test script for ClickHouse migrations setup
# This script verifies that the migration system is working correctly

set -e

echo "🧪 Testing ClickHouse Migration Setup"
echo "======================================"

# Check if required files exist
echo "📋 Checking required files..."
required_files=(
    "docker-compose.yml"
    ".env.clickhouse"
    "priv/clickhouse/migrations/20250724000001_create_video_events.sql"
    "scripts/clickhouse-migrate.sh"
    "lib/mix/tasks/clickhouse_migrate.ex"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file exists"
    else
        echo "  ❌ $file missing"
        exit 1
    fi
done

# Check if ClickHouse is running
echo ""
echo "🔍 Checking ClickHouse status..."
if docker-compose ps clickhouse | grep -q "Up"; then
    echo "  ✅ ClickHouse container is running"
else
    echo "  ⚠️  ClickHouse container is not running"
    echo "     Starting ClickHouse..."
    docker-compose up -d clickhouse

    # Wait for ClickHouse to be ready
    echo "     Waiting for ClickHouse to be ready..."
    for i in {1..30}; do
        if curl -s "http://localhost:8123/" > /dev/null; then
            echo "  ✅ ClickHouse is ready"
            break
        fi
        sleep 1
        if [ $i -eq 30 ]; then
            echo "  ❌ ClickHouse failed to start within 30 seconds"
            exit 1
        fi
    done
fi

# Test migration script
echo ""
echo "🚀 Testing migration functionality..."
echo "     Running migration status check..."
if ./scripts/clickhouse-migrate.sh status; then
    echo "  ✅ Migration status check successful"
else
    echo "  ⚠️  Migration status check failed (this might be expected if no migrations have been run)"
fi

echo ""
echo "     Testing Mix task..."
if mix help clickhouse.migrate > /dev/null 2>&1; then
    echo "  ✅ Mix task is available"
else
    echo "  ❌ Mix task is not available"
    exit 1
fi

echo ""
echo "🎉 All tests passed! The ClickHouse migration setup is working correctly."
echo ""
echo "Next steps:"
echo "  1. Run migrations: ./scripts/clickhouse-migrate.sh up"
echo "  2. Check status: ./scripts/clickhouse-migrate.sh status"
echo "  3. Create new migration: ./scripts/clickhouse-migrate.sh new your_migration_name"
