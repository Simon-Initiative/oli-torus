-- migrate:up
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id String,
    user_id String,
    section_id UInt64,
    started_at DateTime64(3),
    ended_at Nullable(DateTime64(3)),
    page_views UInt32 DEFAULT 0,
    total_time_seconds UInt32 DEFAULT 0,
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (started_at, section_id, user_id)
PARTITION BY toYYYYMM(started_at)
SETTINGS index_granularity = 8192;

-- migrate:down
DROP TABLE IF EXISTS user_sessions;
