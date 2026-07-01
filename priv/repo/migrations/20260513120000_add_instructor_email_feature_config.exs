defmodule Oli.Repo.Migrations.AddInstructorEmailFeatureConfig do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF to_regclass('public.completions_service_configs') IS NOT NULL
         AND to_regclass('public.gen_ai_feature_configs') IS NOT NULL THEN

        INSERT INTO completions_service_configs
          (name, primary_model_id, backup_model_id, inserted_at, updated_at)
        SELECT 'instructor-email-default', primary_model_id, NULL, NOW(), NOW()
          FROM completions_service_configs
         WHERE name = 'standard-no-backup'
           AND NOT EXISTS (
             SELECT 1 FROM completions_service_configs
              WHERE name = 'instructor-email-default'
           )
         LIMIT 1;

        INSERT INTO gen_ai_feature_configs
          (feature, service_config_id, section_id, inserted_at, updated_at)
        SELECT 'instructor_email', id, NULL, NOW(), NOW()
          FROM completions_service_configs
         WHERE name = 'instructor-email-default'
           AND NOT EXISTS (
             SELECT 1 FROM gen_ai_feature_configs
              WHERE feature = 'instructor_email' AND section_id IS NULL
           );
      END IF;
    END $$;
    """)
  end

  def down, do: :ok
end
