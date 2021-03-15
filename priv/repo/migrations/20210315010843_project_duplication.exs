defmodule Oli.Repo.Migrations.ProjectDuplication do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :parent_project_id, references(:projects)
    end

    alter table(:revisions) do
      add :project_id, references(:projects)
    end
  end
end
