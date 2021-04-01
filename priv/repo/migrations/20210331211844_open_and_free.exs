defmodule Oli.Repo.Migrations.OpenAndFree do
  use Ecto.Migration

  def up do
    alter table(:publications) do
      remove :open_and_free, :boolean, default: false, null: false
      remove :description, :string
    end

    alter table(:sections) do
      add_if_not_exists :grade_passback_enabled, :boolean, default: false, null: false
      add_if_not_exists :line_items_service_url, :string
      add_if_not_exists :nrps_enabled, :boolean, default: false, null: false
      add_if_not_exists :nrps_context_memberships_url, :string
    end

    execute("CREATE EXTENSION pg_trgm")
    execute("""
    CREATE INDEX projects_trgm_idx ON projects USING GIN (to_tsvector('english', title || ' ' || description || ' ' || slug))
    """)
  end

  def down do
    execute("DROP INDEX projects_trgm_idx")
    execute("DROP EXTENSION pg_trgm")

    alter table(:sections) do
      remove :grade_passback_enabled, :boolean, default: false, null: false
      remove :line_items_service_url, :string
      remove :nrps_enabled, :boolean, default: false, null: false
      remove :nrps_context_memberships_url, :string
    end

    alter table(:publications) do
      add :open_and_free, :boolean, default: false, null: false
      add :description, :string
    end
  end
end
