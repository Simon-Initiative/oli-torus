-- +goose Up
ALTER TABLE experiment_attributions DROP COLUMN IF EXISTS decision_point_key;
ALTER TABLE experiment_attributions DROP COLUMN IF EXISTS decision_point_id;

-- +goose Down
ALTER TABLE experiment_attributions ADD COLUMN IF NOT EXISTS decision_point_id Nullable(UInt64) AFTER experiment_uuid;
ALTER TABLE experiment_attributions ADD COLUMN IF NOT EXISTS decision_point_key Nullable(String) AFTER decision_point_id;
