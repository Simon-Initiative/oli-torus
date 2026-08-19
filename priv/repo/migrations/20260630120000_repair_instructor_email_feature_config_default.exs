defmodule Oli.Repo.Migrations.RepairInstructorEmailFeatureConfigDefault do
  use Ecto.Migration

  @moduledoc """
  Repairs the global `:instructor_email` GenAI feature config on already-running
  environments (MER-5257 follow-up).

  The original migration `20260513120000_add_instructor_email_feature_config`
  created the global config only when a `completions_service_configs` row named
  exactly `standard-no-backup` existed. Servers seeded before that name was
  introduced (e.g. Tokamaka, Proton) name their bundle `standard`, so the
  `WHERE name = 'standard-no-backup'` select matched nothing and the email
  feature was left unconfigured for every section — `FeatureConfig.load_for/2`
  returns `:missing_feature_config` and the Draft Email modal shows
  "AI email generation is not configured for this course."

  This backfill removes the hardcoded-name dependency: it derives the model from
  the global `student_dialogue` feature config's service config (the canonical
  GenAI default, seeded on every environment), falling back to the lowest-id
  `registered_models` row. Both inserts are guarded by `WHERE NOT EXISTS` because
  the unique index on `[:section_id, :feature]` does not prevent duplicate global
  rows when `section_id IS NULL` (Postgres treats NULLs as distinct), and the
  source selects are bounded to a single deterministic row because
  `completions_service_configs.name` is not unique.

  Intent is to guarantee the feature is *configured*, not to guarantee best
  provider quality; operators can re-point the model afterward via the admin UI.
  `down` is a no-op: deleting a global row later could remove operator-modified
  production configuration.
  """

  def up do
    execute("""
    INSERT INTO completions_service_configs
      (name, primary_model_id, backup_model_id, inserted_at, updated_at)
    SELECT 'instructor-email-default', src.model_id, NULL, NOW(), NOW()
    FROM (
      SELECT COALESCE(
        (SELECT sc.primary_model_id
           FROM gen_ai_feature_configs g
           JOIN completions_service_configs sc ON sc.id = g.service_config_id
          WHERE g.feature = 'student_dialogue' AND g.section_id IS NULL
          ORDER BY g.id
          LIMIT 1),
        (SELECT id FROM registered_models ORDER BY id LIMIT 1)
      ) AS model_id
    ) src
    WHERE src.model_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM completions_service_configs
         WHERE name = 'instructor-email-default'
      )
      AND NOT EXISTS (
        SELECT 1 FROM gen_ai_feature_configs
         WHERE feature = 'instructor_email' AND section_id IS NULL
      );
    """)

    execute("""
    INSERT INTO gen_ai_feature_configs
      (feature, service_config_id, section_id, inserted_at, updated_at)
    SELECT 'instructor_email', sc.id, NULL, NOW(), NOW()
    FROM completions_service_configs sc
    WHERE sc.name = 'instructor-email-default'
      AND NOT EXISTS (
        SELECT 1 FROM gen_ai_feature_configs
         WHERE feature = 'instructor_email' AND section_id IS NULL
      )
    ORDER BY sc.id
    LIMIT 1;
    """)
  end

  def down, do: :ok
end
