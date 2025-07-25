-- +goose Up
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id String,
    user_id String DEFAULT '',
    started_at DateTime64(3),
    ended_at Nullable(DateTime64(3)),
    page_views UInt32 DEFAULT 0,
    total_time_seconds UInt64 DEFAULT 0,
    section_id UInt64 DEFAULT 0,
    browser_info Nullable(String),
    ip_address Nullable(String),
    user_agent Nullable(String),
    inserted_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (started_at, section_id, user_id)
PARTITION BY toYYYYMM(started_at)
SETTINGS index_granularity = 8192;

-- +goose Down
DROP TABLE IF EXISTS user_sessions;
