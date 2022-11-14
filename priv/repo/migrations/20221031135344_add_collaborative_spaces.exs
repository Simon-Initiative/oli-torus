defmodule Oli.Repo.Migrations.AddCollaborativeSpaces do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :collab_space_config, :map
    end
  end
end
