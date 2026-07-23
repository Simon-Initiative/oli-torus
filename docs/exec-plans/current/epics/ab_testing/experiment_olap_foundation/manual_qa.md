# Experiment OLAP Foundation Manual QA

## Purpose

Verify the local end-to-end path for A/B experiment xAPI attribution ingestion:

- Dockerized ClickHouse starts from the `docker-compose.yml` `clickhouse` service.
- Torus development runtime uses the ClickHouse direct uploader.
- Existing host xAPI statements remain one row each in `raw_events`.
- Host statements with `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]` fan out into compact rows in `experiment_attributions`.
- Attribution rows join back to their parent host rows through `experiment_attributions.raw_event_hash = raw_events.event_hash`.

This plan validates the local direct-uploader path only. Production S3/SQS/Lambda parity remains a follow-up verification path documented in `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/fdd.md`.

## Preconditions

- Docker is running.
- PostgreSQL and the normal Torus development dependencies are available.
- `goose` is installed and available on `PATH` for `mix clickhouse.migrate`.
- The branch includes the experiment attribution schema and direct uploader changes.
- The local user can sign in as an author, instructor, and at least two students.
- A course project exists or can be created with an alternatives decision point and an automatically graded activity.

## Local ClickHouse Setup

1. Confirm the compose service exists:

   ```bash
   docker compose config --services
   ```

   Expected result: `clickhouse` is listed.

2. Confirm the ClickHouse user config exists at `clickhouse/users.xml`.

   Expected result: the compose service can mount the tracked development user config into `/etc/clickhouse-server/users.d/dev-users.xml`.

3. Start ClickHouse:

   ```bash
   docker compose up -d clickhouse
   ```

4. Confirm ClickHouse accepts HTTP requests:

   ```bash
   curl -u default:clickhouse "http://localhost:8123/?query=SELECT%201"
   ```

   Expected result: `1`.

5. Configure the Torus development environment for local ClickHouse and the direct uploader in `oli.env`:

   ```env
   CLICKHOUSE_HOST=localhost
   CLICKHOUSE_HTTP_PORT=8123
   CLICKHOUSE_NATIVE_PORT=9090
   CLICKHOUSE_DATABASE=oli_analytics_dev
   CLICKHOUSE_ADMIN_USER=default
   CLICKHOUSE_ADMIN_PASSWORD=clickhouse
   CLICKHOUSE_QUERY_USER=default
   CLICKHOUSE_QUERY_PASSWORD=clickhouse
   CLICKHOUSE_OLAP_ENABLED=true
   XAPI_ETL_MODE=direct
   SUPPRESS_DEV_EVENT_EMITTING=false
   ```

   Note: `config/dev.exs` defaults `XAPI_ETL_MODE` to the direct uploader when unset, but setting it explicitly makes the QA run self-documenting.

6. Create or refresh the ClickHouse schema:

   ```bash
   mix clickhouse.migrate setup
   mix clickhouse.migrate status
   ```

   Expected result: `oli_analytics_dev.raw_events` and `oli_analytics_dev.experiment_attributions` exist, and the experiment attribution migration has run.

7. Start Torus after `oli.env` has been updated:

   ```bash
   mix phx.server
   ```

8. Open `/admin/clickhouse` as an admin user.

   Expected result: the dashboard reports ClickHouse reachable with no pending migration required.

   If the ClickHouse admin page is hidden or reports that ClickHouse analytics are not enabled, enable the `clickhouse-olap` feature state in the local database as well. The UI gate requires both `CLICKHOUSE_OLAP_ENABLED=true` and the persisted `clickhouse-olap` feature flag state to be enabled.

## QA Data Setup

1. Create or identify a project with one page containing an alternatives decision point.
2. Add at least two alternatives, each with distinguishable visible content.
3. Include an automatically graded activity inside each alternative.
4. Create an A/B experiment over the alternatives decision point.
5. Use an active policy:

   - Weighted random is sufficient for exposure attribution.
   - Thompson Sampling is preferred if validating reward and policy-update evidence in the same run.

6. Publish the project and create a delivery section.
7. Enroll at least two student users.

Record these identifiers for the SQL checks:

- `section_id`
- `project_id`
- `publication_id`
- `experiment_id`
- `decision_point_id`
- student user emails

## Exposure Flow

1. Sign in as Student A.
2. Open the delivery page that contains the alternatives decision point.
3. Confirm only one selected alternative is visible.
4. Refresh or revisit the same page.

Expected application result:

- Student A sees the same selected alternative on revisit.
- No dedicated learner xAPI object type for `experiment_event` is emitted.

Expected ClickHouse result:

```bash
docker compose exec clickhouse clickhouse-client \
  --user default \
  --password clickhouse \
  --database oli_analytics_dev \
  --query "
    SELECT
      r.event_type,
      r.has_experiment_attribution,
      r.experiment_attribution_count,
      e.experiment_role,
      e.experiment_id,
      e.decision_point_id,
      e.condition_id,
      e.raw_event_hash = r.event_hash AS joins_parent
    FROM experiment_attributions e
    INNER JOIN raw_events r ON r.event_hash = e.raw_event_hash
    WHERE e.experiment_id = <experiment_id>
      AND e.experiment_role = 'exposure'
    ORDER BY e.timestamp DESC
    LIMIT 10
  "
```

Pass criteria:

- At least one `experiment_attributions` row exists with `experiment_role = 'exposure'`.
- Joined `raw_events.event_type` is `page_viewed`.
- `joins_parent` is `1`.
- Parent `raw_events` has `has_experiment_attribution = 1` and `experiment_attribution_count >= 1`.

## Outcome And Reward Flow

1. As Student A, submit the automatically graded activity inside the selected alternative.
2. Use an answer that receives full credit.
3. Wait for the xAPI batch timeout, or trigger another event if needed to flush the Broadway batch.

Expected application result:

- The attempt is evaluated.
- For Thompson Sampling, policy state reward counters advance once for the reward.

Expected ClickHouse result:

```bash
docker compose exec clickhouse clickhouse-client \
  --user default \
  --password clickhouse \
  --database oli_analytics_dev \
  --query "
    SELECT
      r.event_type,
      r.score,
      r.out_of,
      r.scaled_score,
      e.experiment_role,
      e.reward_value,
      e.reward_source,
      e.outcome_id,
      e.reward_id,
      e.raw_event_hash = r.event_hash AS joins_parent
    FROM experiment_attributions e
    INNER JOIN raw_events r ON r.event_hash = e.raw_event_hash
    WHERE e.experiment_id = <experiment_id>
      AND e.experiment_role IN ('outcome', 'reward')
    ORDER BY e.timestamp DESC
    LIMIT 20
  "
```

Pass criteria:

- Outcome and reward evidence appears on host `part_attempt` rows.
- `reward_value` reflects the scored attempt outcome.
- `reward_source` is populated for reward rows.
- Every attribution row joins to exactly one parent raw event.

## Multiple Attribution Flow

Use this flow if the page can expose more than one active experiment attribution on the same host statement.

1. Configure two active experiments whose selected alternatives are represented by the same page view or attempt host statement.
2. Open the page as Student B.
3. Query the most recent attributed host rows:

   ```bash
   docker compose exec clickhouse clickhouse-client \
     --user default \
     --password clickhouse \
     --database oli_analytics_dev \
     --query "
       SELECT
         r.event_hash,
         r.event_type,
         r.experiment_attribution_count,
         count(e.attribution_hash) AS projected_attributions
       FROM raw_events r
       INNER JOIN experiment_attributions e ON e.raw_event_hash = r.event_hash
       WHERE r.has_experiment_attribution = 1
       GROUP BY r.event_hash, r.event_type, r.experiment_attribution_count
       HAVING projected_attributions > 1
       ORDER BY projected_attributions DESC
       LIMIT 10
     "
   ```

Pass criteria:

- One parent `raw_events` row can project multiple attribution rows.
- `experiment_attribution_count` matches the number of projected rows for that host statement after dedupe has settled.

## Duplicate Reward Guard

1. Re-submit or re-trigger the same evaluated activity attempt for Student A without creating a new distinct rewarded attempt.
2. Inspect the assignment runtime state in PostgreSQL if needed.
3. Query ClickHouse reward attribution counts:

   ```bash
   docker compose exec clickhouse clickhouse-client \
     --user default \
     --password clickhouse \
     --database oli_analytics_dev \
     --query "
       SELECT
         experiment_id,
         assignment_id,
         reward_id,
         count() AS rows,
         uniqExact(attribution_hash) AS unique_attributions
       FROM experiment_attributions
       WHERE experiment_id = <experiment_id>
         AND experiment_role = 'reward'
       GROUP BY experiment_id, assignment_id, reward_id
       ORDER BY rows DESC
     "
   ```

Pass criteria:

- The runtime policy state does not apply the same reward twice.
- ClickHouse analytics can be read with distinct attribution identity without inflated reward counts.

## Media Attribution Flow

Use this flow if a selected alternative contains video/media content that emits xAPI.

1. Add a video/media element inside an experiment alternative.
2. Publish and open the page as a student assigned to that alternative.
3. Play, pause, seek, and complete enough of the media to generate xAPI.
4. Query attributed media rows:

   ```bash
   docker compose exec clickhouse clickhouse-client \
     --user default \
     --password clickhouse \
     --database oli_analytics_dev \
     --query "
       SELECT
         r.event_type,
         r.video_url,
         e.experiment_role,
         e.experiment_id,
         e.condition_id,
         e.raw_event_hash = r.event_hash AS joins_parent
       FROM experiment_attributions e
       INNER JOIN raw_events r ON r.event_hash = e.raw_event_hash
       WHERE e.experiment_id = <experiment_id>
         AND r.event_type = 'video'
       ORDER BY e.timestamp DESC
       LIMIT 20
     "
   ```

Pass criteria:

- Video/media host rows remain in `raw_events`.
- Experiment dimensions live in `experiment_attributions`.
- Detailed media context is read from `raw_events` through `raw_event_hash`.

## Negative Checks

Run these queries after the positive flows:

```bash
docker compose exec clickhouse clickhouse-client \
  --user default \
  --password clickhouse \
  --database oli_analytics_dev \
  --query "
    SELECT count()
    FROM raw_events
    WHERE event_type = 'experiment_event'
       OR verb_id LIKE '%experiment%'
  "
```

Expected result: `0`.

```bash
docker compose exec clickhouse clickhouse-client \
  --user default \
  --password clickhouse \
  --database oli_analytics_dev \
  --query "
    SELECT count()
    FROM raw_events
    WHERE has_experiment_attribution = 1
      AND event_hash NOT IN (
        SELECT raw_event_hash FROM experiment_attributions
      )
  "
```

Expected result: `0`.

## Troubleshooting

- If `docker compose up -d clickhouse` fails with a mount error, confirm `clickhouse/users.xml` exists locally.
- If `mix clickhouse.migrate setup` fails because `goose` is missing, install `goose` and rerun setup.
- If `/admin/clickhouse` reports missing credentials, confirm the `CLICKHOUSE_*` settings are present in `oli.env` before starting `mix phx.server`.
- If no rows appear in ClickHouse, confirm `XAPI_ETL_MODE=direct` and `SUPPRESS_DEV_EVENT_EMITTING=false` are present in `oli.env`, restart `mix phx.server`, and check the app logs for `Oli.Analytics.XAPI.ClickHouseUploader` errors.
- If `raw_events` rows appear but `experiment_attributions` is empty, inspect the host statement JSON in the app logs or local xAPI output to confirm the `experiment_attributions` extension is present and is an array.

## Cleanup

Stop the local service when finished:

```bash
docker compose stop clickhouse
```

To remove local ClickHouse data for a clean rerun:

```bash
docker compose down
docker volume rm oli-torus_clickhouse_data
```

Only remove the volume when local analytics data can be discarded.
