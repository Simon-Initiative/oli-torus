defmodule Oli.Repo.Migrations.OpenAndFree do
  use Ecto.Migration

  def up do
    alter table(:publications) do
      remove :open_and_free, :boolean, default: false, null: false
      remove :description, :string
    end

    execute("CREATE EXTENSION pg_trgm")
    execute("""
    CREATE INDEX projects_trgm_idx ON projects USING GIN (to_tsvector('english', title || ' ' || description || ' ' || slug))
    """)
  end

  def down do
    alter table(:publications) do
      add :open_and_free, :boolean, default: false, null: false
      add :description, :string
    end

    execute("DROP INDEX projects_trgm_idx")
    execute("DROP EXTENSION pg_trgm")
  end
end
