-- +goose Up
ALTER TABLE experiment_attributions
    ADD COLUMN IF NOT EXISTS assignment_scope LowCardinality(String) DEFAULT 'intervention' AFTER assignment_key;

-- +goose Down
ALTER TABLE experiment_attributions
    DROP COLUMN IF EXISTS assignment_scope;
