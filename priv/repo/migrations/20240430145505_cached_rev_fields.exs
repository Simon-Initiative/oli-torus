defmodule Oli.Repo.Migrations.CachedRevFields do
  use Ecto.Migration

  def change do
    create table(:section_resource_summary) do

      add :section_id, references(:sections)
      add :resource_id, references(:resources)
      add :title, :string
      add :graded, :boolean
      add :resource_type_id, references(:resource_types)
      add :activity_type_id, references(:activity_registrations)

      timestamps(type: :timestamptz)
    end
    create unique_index(:section_resource_summary, [:section_id, :resource_id], name: :section_resource_summary_section_resource)
  end
end
