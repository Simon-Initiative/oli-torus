defmodule Oli.Repo.Migrations.AddAiEnabledToRevisionsAndSectionResources do
  use Ecto.Migration

  def up do
    alter table(:revisions) do
      add :ai_enabled, :boolean
    end

    execute("""
    UPDATE revisions
    SET ai_enabled =
      CASE
        WHEN graded IS TRUE THEN FALSE
        WHEN graded IS FALSE THEN TRUE
        ELSE NULL
      END
    WHERE ai_enabled IS NULL
    """)

    alter table(:section_resources) do
      add :ai_enabled, :boolean
    end

    execute("""
    UPDATE section_resources
    SET ai_enabled =
      CASE
        WHEN graded IS TRUE THEN FALSE
        WHEN graded IS FALSE THEN TRUE
        ELSE NULL
      END
    WHERE ai_enabled IS NULL
    """)
  end

  def down do
    alter table(:section_resources) do
      remove :ai_enabled
    end

    alter table(:revisions) do
      remove :ai_enabled
    end
  end
end
