-- +goose Up
-- Add retention policy to raw_events and create rollup aggregates.

-- Keep 18 months of raw events based on event time.
ALTER TABLE raw_events
  MODIFY TTL timestamp + INTERVAL 18 MONTH;

-- Daily rollups (aggregating states to support incremental MV inserts).
CREATE TABLE IF NOT EXISTS raw_events_daily_agg
(
    rollup_date Date,
    section_id UInt64,
    project_id UInt64,
    event_type LowCardinality(String),
    total_events_state AggregateFunction(count, UInt64),
    unique_users_state AggregateFunction(uniq, String),
    min_event_time_state AggregateFunction(min, DateTime64(3)),
    max_event_time_state AggregateFunction(max, DateTime64(3)),
    sum_score_state AggregateFunction(sum, Float64),
    sum_out_of_state AggregateFunction(sum, Float64),
    sum_scaled_score_state AggregateFunction(sum, Float64),
    sum_video_play_time_state AggregateFunction(sum, Float64),
    sum_video_progress_state AggregateFunction(sum, Float64),
    sum_video_length_state AggregateFunction(sum, Float64),
    completion_count_state AggregateFunction(sum, UInt64),
    success_count_state AggregateFunction(sum, UInt64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(rollup_date)
ORDER BY (rollup_date, section_id, project_id, event_type);

CREATE MATERIALIZED VIEW IF NOT EXISTS raw_events_daily_agg_mv
TO raw_events_daily_agg
AS
SELECT
    toDate(timestamp) AS rollup_date,
    section_id,
    project_id,
    event_type,
    countState() AS total_events_state,
    uniqState(user_id) AS unique_users_state,
    minState(timestamp) AS min_event_time_state,
    maxState(timestamp) AS max_event_time_state,
    sumState(ifNull(score, 0)) AS sum_score_state,
    sumState(ifNull(out_of, 0)) AS sum_out_of_state,
    sumState(ifNull(scaled_score, 0)) AS sum_scaled_score_state,
    sumState(ifNull(video_play_time, 0)) AS sum_video_play_time_state,
    sumState(ifNull(video_progress, 0)) AS sum_video_progress_state,
    sumState(ifNull(video_length, 0)) AS sum_video_length_state,
    sumState(if(completion, 1, 0)) AS completion_count_state,
    sumState(if(success, 1, 0)) AS success_count_state
FROM raw_events
GROUP BY rollup_date, section_id, project_id, event_type;

-- Weekly rollups (week starts on Monday using toStartOfWeek).
CREATE TABLE IF NOT EXISTS raw_events_weekly_agg
(
    rollup_week_start Date,
    section_id UInt64,
    project_id UInt64,
    event_type LowCardinality(String),
    total_events_state AggregateFunction(count, UInt64),
    unique_users_state AggregateFunction(uniq, String),
    min_event_time_state AggregateFunction(min, DateTime64(3)),
    max_event_time_state AggregateFunction(max, DateTime64(3)),
    sum_score_state AggregateFunction(sum, Float64),
    sum_out_of_state AggregateFunction(sum, Float64),
    sum_scaled_score_state AggregateFunction(sum, Float64),
    sum_video_play_time_state AggregateFunction(sum, Float64),
    sum_video_progress_state AggregateFunction(sum, Float64),
    sum_video_length_state AggregateFunction(sum, Float64),
    completion_count_state AggregateFunction(sum, UInt64),
    success_count_state AggregateFunction(sum, UInt64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(rollup_week_start)
ORDER BY (rollup_week_start, section_id, project_id, event_type);

CREATE MATERIALIZED VIEW IF NOT EXISTS raw_events_weekly_agg_mv
TO raw_events_weekly_agg
AS
SELECT
    toDate(toStartOfWeek(timestamp)) AS rollup_week_start,
    section_id,
    project_id,
    event_type,
    countState() AS total_events_state,
    uniqState(user_id) AS unique_users_state,
    minState(timestamp) AS min_event_time_state,
    maxState(timestamp) AS max_event_time_state,
    sumState(ifNull(score, 0)) AS sum_score_state,
    sumState(ifNull(out_of, 0)) AS sum_out_of_state,
    sumState(ifNull(scaled_score, 0)) AS sum_scaled_score_state,
    sumState(ifNull(video_play_time, 0)) AS sum_video_play_time_state,
    sumState(ifNull(video_progress, 0)) AS sum_video_progress_state,
    sumState(ifNull(video_length, 0)) AS sum_video_length_state,
    sumState(if(completion, 1, 0)) AS completion_count_state,
    sumState(if(success, 1, 0)) AS success_count_state
FROM raw_events
GROUP BY rollup_week_start, section_id, project_id, event_type;

-- +goose Down
DROP TABLE IF EXISTS raw_events_weekly_agg_mv;
DROP TABLE IF EXISTS raw_events_weekly_agg;
DROP TABLE IF EXISTS raw_events_daily_agg_mv;
DROP TABLE IF EXISTS raw_events_daily_agg;

ALTER TABLE raw_events
  REMOVE TTL;
