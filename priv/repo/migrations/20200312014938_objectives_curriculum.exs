defmodule Oli.Repo.Migrations.ObjectivesCurriculum do
  use Ecto.Migration

  def change do
    create table(:objectives) do
      timestamps()
      add :description, :string
      add :project_id, references(:projects)
    end

    create table(:objectives_objectives) do
      timestamps()
      add :parent_id, references(:objectives)
      add :child_id, references(:objectives)
    end

    create table(:pages_with_position) do
      timestamps()
      add :project_id, references(:projects)
      add :page_id, references(:resources)
      add :position, :integer
    end
  end
end
