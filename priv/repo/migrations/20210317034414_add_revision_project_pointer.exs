defmodule Oli.Repo.Migrations.AddIsBaseToPublishedResource do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :project_id, references(:projects)
    end
  end
end
