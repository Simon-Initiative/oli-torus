-- +goose Up
CREATE TABLE IF NOT EXISTS page_viewed_events (
    event_id String,
    user_id String,
    host_name String,
    section_id UInt64,
    project_id UInt64,
    publication_id UInt64,
    page_attempt_guid String,
    page_attempt_number UInt32,
    page_id UInt64,
    page_sub_type Nullable(String),
    timestamp DateTime64(3),
    success Nullable(Bool),
    completion Nullable(Bool),
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (timestamp, section_id, user_id)
PARTITION BY toYYYYMM(timestamp)
SETTINGS index_granularity = 8192;

-- +goose Down
DROP TABLE IF EXISTS page_viewed_events;
