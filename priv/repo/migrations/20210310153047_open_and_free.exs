defmodule Oli.Repo.Migrations.OpenAndFree do
  use Ecto.Migration

  def up do
    alter table(:publications) do
      remove :open_and_free, :boolean, default: false, null: false
    end

    execute("CREATE EXTENSION pg_trgm")
  end

  def down do
    alter table(:publications) do
      add :open_and_free, :boolean, default: false, null: false
    end

    execute("DROP EXTENSION pg_trgm")
  end
end
