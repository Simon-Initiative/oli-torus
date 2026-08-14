-- +goose Up
ALTER TABLE experiment_attributions
    ADD COLUMN IF NOT EXISTS intervention_id Nullable(UInt64),
    ADD COLUMN IF NOT EXISTS intervention_key Nullable(String),
    ADD COLUMN IF NOT EXISTS assessment_binding_id Nullable(UInt64),
    ADD COLUMN IF NOT EXISTS assessment_page_resource_id Nullable(UInt64),
    ADD COLUMN IF NOT EXISTS resource_attempt_id Nullable(UInt64),
    ADD COLUMN IF NOT EXISTS disposition Nullable(String),
    ADD COLUMN IF NOT EXISTS reward_threshold Nullable(Float64),
    ADD COLUMN IF NOT EXISTS normalized_score Nullable(Float64),
    ADD COLUMN IF NOT EXISTS page_revision_id Nullable(UInt64);

-- +goose Down
ALTER TABLE experiment_attributions
    DROP COLUMN IF EXISTS page_revision_id,
    DROP COLUMN IF EXISTS normalized_score,
    DROP COLUMN IF EXISTS reward_threshold,
    DROP COLUMN IF EXISTS disposition,
    DROP COLUMN IF EXISTS resource_attempt_id,
    DROP COLUMN IF EXISTS assessment_page_resource_id,
    DROP COLUMN IF EXISTS assessment_binding_id,
    DROP COLUMN IF EXISTS intervention_key,
    DROP COLUMN IF EXISTS intervention_id;
