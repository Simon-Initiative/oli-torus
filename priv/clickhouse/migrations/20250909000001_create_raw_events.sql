-- +goose Up
-- Raw events table for all XAPI event types
-- This table consolidates all event types into a single table for better performance and simplified queries
CREATE TABLE IF NOT EXISTS raw_events (
    -- Core event fields (required for all events)
    event_id String,
    user_id String,
    host_name String,
    section_id UInt64,
    project_id UInt64,
    publication_id UInt64,
    timestamp DateTime64(3),
    event_type LowCardinality(String), -- 'video', 'activity_attempt', 'page_attempt', 'page_viewed', 'part_attempt'

    -- Common attempt tracking fields (nullable for events that don't use them)
    attempt_guid Nullable(String),
    attempt_number Nullable(UInt32),
    page_id Nullable(UInt64),

    -- Video-specific fields (nullable)
    content_element_id Nullable(String),
    video_url Nullable(String),
    video_title Nullable(String),
    video_time Nullable(Float64),
    video_length Nullable(Float64),
    video_progress Nullable(Float64),
    video_played_segments Nullable(String),
    video_play_time Nullable(Float64),
    video_seek_from Nullable(Float64),
    video_seek_to Nullable(Float64),

    -- Activity/Page/Part specific fields (nullable)
    activity_attempt_guid Nullable(String),
    activity_attempt_number Nullable(UInt32),
    page_attempt_guid Nullable(String),
    page_attempt_number Nullable(UInt32),
    part_attempt_guid Nullable(String),
    part_attempt_number Nullable(UInt32),
    activity_id Nullable(UInt64),
    activity_revision_id Nullable(UInt64),
    part_id Nullable(String),

    -- Page-specific fields (nullable)
    page_sub_type Nullable(String),

    -- Result fields (nullable)
    score Nullable(Float64),
    out_of Nullable(Float64),
    scaled_score Nullable(Float64),
    success Nullable(Bool),
    completion Nullable(Bool),
    response Nullable(String),
    feedback Nullable(String),

    -- Part attempt specific fields (nullable)
    hints_requested Nullable(UInt32),
    attached_objectives Nullable(String),
    session_id Nullable(String),

    -- Metadata
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (timestamp, section_id, user_id, event_type)
PARTITION BY toYYYYMM(timestamp)
SETTINGS index_granularity = 8192;

-- Create indexes for common query patterns
-- Index on section_id for section-specific queries
ALTER TABLE raw_events ADD INDEX idx_section_id section_id TYPE minmax GRANULARITY 1;

-- Index on event_type for filtering by event type
ALTER TABLE raw_events ADD INDEX idx_event_type event_type TYPE set(0) GRANULARITY 1;

-- Index on user_id for user-specific queries
ALTER TABLE raw_events ADD INDEX idx_user_id user_id TYPE bloom_filter() GRANULARITY 1;

-- +goose Down
DROP TABLE IF EXISTS raw_events;
