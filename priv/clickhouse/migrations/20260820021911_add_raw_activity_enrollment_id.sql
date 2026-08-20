-- +goose Up
ALTER TABLE raw_events ADD COLUMN IF NOT EXISTS enrollment_id Nullable(UInt64) AFTER publication_id;

-- +goose Down
ALTER TABLE raw_events DROP COLUMN IF EXISTS enrollment_id;
