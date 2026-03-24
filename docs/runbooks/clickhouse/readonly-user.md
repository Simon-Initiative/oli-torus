# ClickHouse Read-Only User for Custom Analytics

This runbook describes how to create a dedicated ClickHouse user for instructor custom analytics queries. The user must be limited to SELECT-only access with resource limits to protect cluster performance.

## Preconditions

- ClickHouse admin access (SQL or users.d config access).
- The analytics database name (defaults to `CLICKHOUSE_DATABASE`, usually `default`).
- A password policy and secret storage location for service credentials.

## Option A: Create the user with SQL (recommended for managed ClickHouse)

Run these statements as a ClickHouse admin user (via `clickhouse-client` or the HTTP interface).

```sql
CREATE USER IF NOT EXISTS oli_analytics_ro
  IDENTIFIED WITH sha256_password BY '<strong-password>';

GRANT SELECT ON <database>.* TO oli_analytics_ro;

ALTER USER oli_analytics_ro SETTINGS
  readonly = 1,
  max_execution_time = 30,
  max_result_rows = 100000,
  max_rows_to_read = 5000000,
  max_bytes_to_read = 1000000000,
  max_memory_usage = 2000000000;
```

Notes:
- Replace `<database>` with the analytics database (for example `default`).
- Adjust limits to match your performance targets and cluster capacity.
- If `sha256_password` is not supported by your ClickHouse version, use an equivalent secure method (for example `bcrypt_password`). Avoid plaintext passwords in production.

### Optional: allow schema introspection

Custom analytics editors sometimes benefit from schema inspection. If you want to allow it, grant read access to system metadata tables:

```sql
GRANT SELECT ON system.tables TO oli_analytics_ro;
GRANT SELECT ON system.columns TO oli_analytics_ro;
```

## Option B: Create the user via users.d (self-hosted ClickHouse)

1. Create a file like `/etc/clickhouse-server/users.d/oli-analytics-ro.xml`.
2. Generate a SHA-256 hex digest for the password (example using `openssl`):

```bash
printf '%s' 'your-strong-password' | openssl dgst -sha256 -hex | awk '{print $2}'
```

3. Add a user definition and a profile that includes read-only limits:

```xml
<clickhouse>
  <users>
    <oli_analytics_ro>
      <password_sha256_hex><!-- sha256 of password --></password_sha256_hex>
      <networks>
        <ip>::/0</ip>
      </networks>
      <profile>oli_analytics_ro</profile>
      <quota>oli_analytics_ro</quota>
    </oli_analytics_ro>
  </users>

  <profiles>
    <oli_analytics_ro>
      <readonly>1</readonly>
      <max_execution_time>30</max_execution_time>
      <max_result_rows>100000</max_result_rows>
      <max_rows_to_read>5000000</max_rows_to_read>
      <max_bytes_to_read>1000000000</max_bytes_to_read>
      <max_memory_usage>2000000000</max_memory_usage>
    </oli_analytics_ro>
  </profiles>

  <quotas>
    <oli_analytics_ro>
      <interval>
        <duration>3600</duration>
        <queries>0</queries>
        <errors>0</errors>
        <result_rows>0</result_rows>
        <read_rows>0</read_rows>
        <execution_time>0</execution_time>
      </interval>
    </oli_analytics_ro>
  </quotas>
</clickhouse>
```

4. Reload ClickHouse or restart the service so the new user is applied.

```sql
SYSTEM RELOAD CONFIG;
```

If `systemctl reload clickhouse-server` is not supported, use the SQL command above or restart the service.

## Verification

1. Authenticate as the read-only user.
2. Run a harmless query:

```sql
SELECT count(*) FROM <database>.raw_events LIMIT 1;
```

3. Confirm that write operations are rejected:

```sql
INSERT INTO <database>.raw_events VALUES (...);
```

## Operational Notes

- Keep the read-only user credentials in your secret manager and rotate them regularly.
- Do not reuse write-capable credentials for instructor custom analytics queries.
- If you need to tighten limits in production, adjust the user settings/profile and reload ClickHouse.
