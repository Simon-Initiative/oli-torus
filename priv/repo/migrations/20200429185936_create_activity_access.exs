defmodule Oli.Repo.Migrations.CreateActivityAccess do
  use Ecto.Migration

  def change do
    create table(:activity_access) do
      add :user_id, :string
      add :section_id, references(:sections)
      add :resource_slug, :string
      add :access_count, :integer
      add :last_accessed, :utc_datetime
      add :date_finished, :utc_datetime
      add :finished_late, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create index(:activity_access, [:section_id])
  end
end
