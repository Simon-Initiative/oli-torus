-- +goose Up
-- +goose StatementBegin
ALTER TABLE raw_events DROP COLUMN event_id;
ALTER TABLE raw_events MODIFY COLUMN user_id Nullable(String);
ALTER TABLE raw_events MODIFY COLUMN section_id Nullable(UInt64);
ALTER TABLE raw_events MODIFY COLUMN project_id Nullable(UInt64);
ALTER TABLE raw_events MODIFY COLUMN publication_id Nullable(UInt64);
ALTER TABLE raw_events MODIFY COLUMN timestamp Nullable(DateTime64(3));
ALTER TABLE raw_events ADD COLUMN home_page Nullable(String) AFTER user_id;
ALTER TABLE raw_events DROP COLUMN host_name;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE raw_events ADD COLUMN host_name String AFTER user_id;
ALTER TABLE raw_events DROP COLUMN home_page;
ALTER TABLE raw_events MODIFY COLUMN timestamp DateTime64(3);
ALTER TABLE raw_events MODIFY COLUMN publication_id UInt64;
ALTER TABLE raw_events MODIFY COLUMN project_id UInt64;
ALTER TABLE raw_events MODIFY COLUMN section_id UInt64;
ALTER TABLE raw_events MODIFY COLUMN user_id String;
ALTER TABLE raw_events ADD COLUMN event_id String FIRST;
-- +goose StatementEnd
