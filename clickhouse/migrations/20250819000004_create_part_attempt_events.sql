-- +goose Up
CREATE TABLE IF NOT EXISTS part_attempt_events (
    event_id String,
    user_id String,
    host_name String,
    section_id UInt64,
    project_id UInt64,
    publication_id UInt64,
    part_attempt_guid String,
    part_attempt_number UInt32,
    activity_attempt_guid String,
    activity_attempt_number UInt32,
    page_attempt_guid String,
    page_attempt_number UInt32,
    page_id UInt64,
    activity_id UInt64,
    activity_revision_id UInt64,
    part_id String,
    timestamp DateTime64(3),
    score Nullable(Float64),
    out_of Nullable(Float64),
    scaled_score Nullable(Float64),
    success Nullable(Bool),
    completion Nullable(Bool),
    response Nullable(String),
    feedback Nullable(String),
    hints_requested Nullable(UInt32),
    attached_objectives Nullable(String),
    session_id Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (timestamp, section_id, user_id)
PARTITION BY toYYYYMM(timestamp)
SETTINGS index_granularity = 8192;

-- +goose Down
DROP TABLE IF EXISTS part_attempt_events;
