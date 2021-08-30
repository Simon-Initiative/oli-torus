defmodule Oli.Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :tags, {:array, :id}
    end
  end

end
