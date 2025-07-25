# ClickHouse Migrations

This directory contains ClickHouse database migrations managed by [dbmate](https://github.com/amacneil/dbmate).

## Setup

### Prerequisites

- Docker and Docker Compose
- ClickHouse service running (via `docker-compose up -d clickhouse`)

### Development

1. **Start ClickHouse**:

   ```bash
   docker-compose up -d clickhouse
   ```

2. **Run migrations**:

   ```bash
   # Using the helper script
   ./scripts/clickhouse-migrate.sh up

   # Or using Mix task
   mix clickhouse.migrate up

   # Or using docker-compose
   docker-compose --profile migrate up clickhouse-migrate
   ```

3. **Create a new migration**:

   ```bash
   ./scripts/clickhouse-migrate.sh new add_user_sessions_table
   ```

4. **Check migration status**:
   ```bash
   ./scripts/clickhouse-migrate.sh status
   ```

## Migration Files

Migration files are stored in `priv/clickhouse/migrations/` and follow the naming convention:

```
YYYYMMDDHHMMSS_description.sql
```

Each migration file should contain:

```sql
-- migrate:up
CREATE TABLE example (
    id UInt64,
    name String
) ENGINE = MergeTree()
ORDER BY id;

-- migrate:down
DROP TABLE IF EXISTS example;
```

## Production Deployment

Migrations are automatically run during deployment via GitHub Actions. The workflow:

1. Connects to the production ClickHouse instance
2. Runs pending migrations using dbmate
3. Verifies migration status

### Environment Variables

Configure these secrets in GitHub Actions:

- `CLICKHOUSE_HOST`: ClickHouse server hostname (without protocol)
- `CLICKHOUSE_USER`: ClickHouse username
- `CLICKHOUSE_PASSWORD`: ClickHouse password (optional)
- `CLICKHOUSE_DATABASE`: Target database name

## Available Commands

### Shell Script (`./scripts/clickhouse-migrate.sh`)

- `up` - Run pending migrations
- `down` - Rollback the last migration
- `status` - Show migration status
- `new <name>` - Create a new migration file
- `create` - Create the database
- `drop` - Drop the database
- `migrate-docker` - Run migrations using docker-compose

### Mix Task (`mix clickhouse.migrate`)

- `mix clickhouse.migrate` or `mix clickhouse.migrate up` - Run pending migrations
- `mix clickhouse.migrate down` - Rollback the last migration
- `mix clickhouse.migrate status` - Show migration status
- `mix clickhouse.migrate create` - Create the database
- `mix clickhouse.migrate drop` - Drop the database

## Configuration

### Development (`.env.clickhouse`)

```env
DATABASE_URL=clickhouse://default@localhost:8123/default
DBMATE_MIGRATIONS_DIR=priv/clickhouse/migrations
DBMATE_NO_DUMP_SCHEMA=true
```

### Application Configuration

ClickHouse connection settings are configured in your Elixir application:

```elixir
config :oli,
  clickhouse_host: "http://localhost",
  clickhouse_port: 8123,
  clickhouse_user: "default",
  clickhouse_password: "",
  clickhouse_database: "default"
```

## Best Practices

1. **Always test migrations locally** before deploying to production
2. **Use reversible migrations** with both `migrate:up` and `migrate:down` sections
3. **Keep migrations atomic** - each migration should be a single logical change
4. **Use appropriate ClickHouse table engines** (usually MergeTree for analytics data)
5. **Consider partitioning** for time-series data using `PARTITION BY toYYYYMM(timestamp)`
6. **Index properly** using `ORDER BY` clauses that match your query patterns

## Troubleshooting

### ClickHouse Connection Issues

1. Ensure ClickHouse is running: `docker-compose ps clickhouse`
2. Check ClickHouse logs: `docker-compose logs clickhouse`
3. Test connection: `curl http://localhost:8123/`

### Migration Failures

1. Check dbmate output for specific error messages
2. Verify SQL syntax is compatible with ClickHouse
3. Ensure the database exists before running migrations
4. Check migration file permissions and format
