-- +goose Up
CREATE TABLE IF NOT EXISTS video_events (
    event_id String,
    timestamp DateTime64(3),
    user_id String DEFAULT '',
    session_id Nullable(String),
    section_id UInt64 DEFAULT 0,
    page_id Nullable(UInt64),
    content_element_id Nullable(String),
    video_url Nullable(String),
    video_title Nullable(String),
    verb Nullable(String),
    video_time Nullable(Float64),
    video_length Nullable(Float64),
    video_progress Nullable(Float64),
    video_played_segments Nullable(String),
    video_play_time Nullable(Float64),
    video_seek_from Nullable(Float64),
    video_seek_to Nullable(Float64),
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (timestamp, section_id, user_id)
PARTITION BY toYYYYMM(timestamp)
SETTINGS index_granularity = 8192;

-- +goose Down
DROP TABLE IF EXISTS video_events;
