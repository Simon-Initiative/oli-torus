defmodule Oli.Repo.Migrations.AddSectionsSearchIndexes do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # enrollments - to order by inserted at
    create index(:enrollments, [:inserted_at])

    # enrollments context roles - composite index in foreign keys
    create index(:enrollments_context_roles, [:enrollment_id, :context_role_id])

    # sections - index in foreign keys
    create index(:sections, [:institution_id])
    create index(:sections, [:base_project_id])
    create index(:sections, [:blueprint_id])

    # sections - index to compare dates
    create index(:sections, [:start_date, :end_date])

    # full text search indexes
    execute("CREATE INDEX sections_title_trgm_idx ON sections USING GIN (to_tsvector('english', title))")
    execute("CREATE INDEX institutions_name_trgm_idx ON institutions USING GIN (to_tsvector('english', name))")
    execute("CREATE INDEX projects_title_trgm_idx ON projects USING GIN (to_tsvector('english', title))")
    execute("CREATE INDEX users_name_trgm_idx ON users USING GIN (to_tsvector('english', name))")
  end

  def down do
    drop index(:enrollments, [:inserted_at])
    drop index(:enrollments_context_roles, [:enrollment_id, :context_role_id])
    drop index(:sections, [:institution_id])
    drop index(:sections, [:base_project_id])
    drop index(:sections, [:blueprint_id])
    drop index(:sections, [:start_date, :end_date])

    execute("DROP INDEX sections_title_trgm_idx")
    execute("DROP INDEX institutions_name_trgm_idx")
    execute("DROP INDEX projects_title_trgm_idx")
    execute("DROP INDEX users_name_trgm_idx")

    execute("DROP EXTENSION pg_trgm")
  end
end
