defmodule Oli.Repo.Migrations.RemoveUnusedInstructorDashboardGenAiFeatureConfig do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF to_regclass('public.gen_ai_feature_configs') IS NOT NULL THEN
        DELETE FROM gen_ai_feature_configs
        WHERE feature = 'instructor_dashboard';
      END IF;
    END $$;
    """)
  end

  def down do
    :ok
  end
end
