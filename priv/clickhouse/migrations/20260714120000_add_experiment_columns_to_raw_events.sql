-- +goose Up
ALTER TABLE raw_events ADD COLUMN IF NOT EXISTS has_experiment_attribution Bool DEFAULT false;
ALTER TABLE raw_events ADD COLUMN IF NOT EXISTS experiment_attribution_count UInt16 DEFAULT 0;
ALTER TABLE raw_events ADD INDEX IF NOT EXISTS idx_has_experiment_attribution has_experiment_attribution TYPE set(0) GRANULARITY 1;

CREATE TABLE IF NOT EXISTS experiment_attributions (
    raw_event_hash String,
    attribution_hash String,
    event_version DateTime64(3) DEFAULT now64(3),
    inserted_at DateTime DEFAULT now(),
    source_file Nullable(String),
    source_etag Nullable(String),
    source_line Nullable(UInt32),

    host_event_type LowCardinality(String),
    timestamp DateTime64(3),
    section_id Nullable(UInt64),
    project_id Nullable(UInt64),
    publication_id Nullable(UInt64),
    enrollment_id Nullable(UInt64),

    experiment_role LowCardinality(String),
    experiment_id Nullable(UInt64),
    experiment_uuid Nullable(String),
    decision_point_id Nullable(UInt64),
    decision_point_key Nullable(String),
    condition_id Nullable(UInt64),
    condition_code Nullable(String),
    assignment_id Nullable(UInt64),
    assignment_key Nullable(String),
    algorithm Nullable(String),
    policy_version Nullable(String),
    algorithm_version Nullable(String),
    idempotency_key Nullable(String),
    idempotency_key_hash Nullable(String),

    content_revision_id Nullable(UInt64),
    outcome_id Nullable(String),
    reward_id Nullable(String),
    reward_value Nullable(Float64),
    reward_source Nullable(String),
    policy_update_reason Nullable(String),
    previous_policy_state_hash Nullable(String),
    next_policy_state_hash Nullable(String)
) ENGINE = ReplacingMergeTree(event_version)
ORDER BY (raw_event_hash, attribution_hash)
PRIMARY KEY (raw_event_hash, attribution_hash)
PARTITION BY toYYYYMM(timestamp)
SETTINGS allow_nullable_key = 0, index_granularity = 8192, insert_deduplicate = 1;

ALTER TABLE experiment_attributions ADD INDEX IF NOT EXISTS idx_experiment_id experiment_id TYPE minmax GRANULARITY 1;
ALTER TABLE experiment_attributions ADD INDEX IF NOT EXISTS idx_experiment_role experiment_role TYPE set(0) GRANULARITY 1;
ALTER TABLE experiment_attributions ADD INDEX IF NOT EXISTS idx_condition_id condition_id TYPE minmax GRANULARITY 1;
ALTER TABLE experiment_attributions ADD INDEX IF NOT EXISTS idx_assignment_id assignment_id TYPE minmax GRANULARITY 1;
ALTER TABLE experiment_attributions ADD INDEX IF NOT EXISTS idx_idempotency_key_hash idempotency_key_hash TYPE bloom_filter() GRANULARITY 1;

-- +goose Down
DROP TABLE IF EXISTS experiment_attributions;
ALTER TABLE raw_events DROP INDEX IF EXISTS idx_has_experiment_attribution;
ALTER TABLE raw_events DROP COLUMN IF EXISTS experiment_attribution_count;
ALTER TABLE raw_events DROP COLUMN IF EXISTS has_experiment_attribution;
