defmodule Oli.Repo.Migrations.AddOriginalPromptToRecommendationInstances do
  use Ecto.Migration

  def change do
    alter table(:instructor_dashboard_recommendation_instances) do
      add :original_prompt, :map, null: false, default: %{}
    end
  end
end
