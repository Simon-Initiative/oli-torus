defmodule Oli.Repo.Migrations.AddProjectAttributes do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :attributes, :map
    end
  end
end
