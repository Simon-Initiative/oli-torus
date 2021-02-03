defmodule Oli.Repo.Migrations.CreateProjectVisibilities do
  use Ecto.Migration

  def change do
    create table(:project_visibilities) do
      add :project_id, :integer
      add :author_id, :integer
      add :institution_id, :integer

      timestamps(type: :timestamptz)
    end

    create index(:project_visibilities, [:project_id])
    create index(:project_visibilities, [:author_id])
    create index(:project_visibilities, [:institution_id])

    alter table(:projects) do
      add :visibility, :string
    end

  end
end
