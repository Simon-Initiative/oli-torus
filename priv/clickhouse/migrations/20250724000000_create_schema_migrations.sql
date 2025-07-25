-- +goose Up
CREATE TABLE IF NOT EXISTS schema_migrations (
    version String,
    dirty UInt8 DEFAULT 0,
    inserted_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY version
SETTINGS index_granularity = 8192;

-- +goose Down
DROP TABLE IF EXISTS schema_migrations;
