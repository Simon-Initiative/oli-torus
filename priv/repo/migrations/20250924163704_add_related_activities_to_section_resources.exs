defmodule Oli.Repo.Migrations.AddRelatedActivitiesToSectionResources do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :related_activities, {:array, :bigint}, null: false, default: []
    end
  end
end
