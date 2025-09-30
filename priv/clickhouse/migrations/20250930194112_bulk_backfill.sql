-- +goose Up
-- +goose StatementBegin

-- Idempotency/metadata
ALTER TABLE raw_events (
    ADD COLUMN IF NOT EXISTS event_hash String,
    ADD COLUMN IF NOT EXISTS event_version UInt32 DEFAULT 1,
    ADD COLUMN IF NOT EXISTS source_file Nullable(String),
    ADD COLUMN IF NOT EXISTS source_etag Nullable(String),
    ADD COLUMN IF NOT EXISTS source_line Nullable(UInt32)
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE raw_events (
    DROP COLUMN IF EXISTS event_hash,
    DROP COLUMN IF EXISTS event_version,
    DROP COLUMN IF EXISTS source_file,
    DROP COLUMN IF EXISTS source_etag,
    DROP COLUMN IF EXISTS source_line
);

-- +goose StatementEnd
