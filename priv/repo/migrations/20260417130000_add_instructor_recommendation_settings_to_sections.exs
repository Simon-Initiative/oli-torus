defmodule Oli.Repo.Migrations.AddInstructorRecommendationSettingsToSections do
  use Ecto.Migration

  def up do
    alter table(:sections) do
      add :instructor_recommendations_enabled, :boolean, default: true, null: false
      add :instructor_recommendation_prompt_template, :text
    end

    execute(
      "UPDATE sections SET instructor_recommendations_enabled = true WHERE instructor_recommendations_enabled IS NULL"
    )
  end

  def down do
    alter table(:sections) do
      remove :instructor_recommendation_prompt_template
      remove :instructor_recommendations_enabled
    end
  end
end
