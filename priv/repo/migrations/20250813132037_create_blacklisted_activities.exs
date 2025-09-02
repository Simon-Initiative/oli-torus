defmodule Oli.Repo.Migrations.CreateBlacklistedActivities do
  use Ecto.Migration

  def change do
    create table(:blacklisted_activities) do
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :activity_id, :bigint, null: false
      add :selection_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blacklisted_activities, [:section_id, :activity_id, :selection_id])
    create index(:blacklisted_activities, [:section_id])
  end
end
