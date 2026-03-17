-- +goose Up
-- +goose StatementBegin
ALTER TABLE raw_events DROP COLUMN event_id;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE raw_events ADD COLUMN event_id String FIRST;
-- +goose StatementEnd
