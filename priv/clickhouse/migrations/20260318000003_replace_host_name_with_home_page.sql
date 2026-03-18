-- +goose Up
-- +goose StatementBegin
ALTER TABLE raw_events ADD COLUMN home_page String AFTER user_id;
ALTER TABLE raw_events DROP COLUMN host_name;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE raw_events ADD COLUMN host_name String AFTER user_id;
ALTER TABLE raw_events DROP COLUMN home_page;
-- +goose StatementEnd
