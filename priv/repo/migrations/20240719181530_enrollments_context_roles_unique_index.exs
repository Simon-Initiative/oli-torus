defmodule Oli.Repo.Migrations.EnrollmentsContextRolesUniqueIndex do
  use Ecto.Migration

  def up do
    # add temporary auto incrementing primary key column for duplicates removal operation
    execute("ALTER TABLE enrollments_context_roles ADD COLUMN id SERIAL PRIMARY KEY")

    # delete duplicate enrollments_context_roles
    execute("""
      DELETE FROM enrollments_context_roles
      WHERE id IN (
          SELECT id FROM (
              SELECT id, ROW_NUMBER() OVER (PARTITION BY enrollment_id, context_role_id ORDER BY id) AS rnum
              FROM enrollments_context_roles
          ) t
          WHERE t.rnum > 1
      )
    """)

    # drop existing non-unique index
    drop index(:enrollments_context_roles, [:enrollment_id, :context_role_id])

    # create unique index
    create unique_index(:enrollments_context_roles, [:enrollment_id, :context_role_id])

    # drop temporary primary key column
    execute("ALTER TABLE enrollments_context_roles DROP COLUMN id")
  end

  def down do
    # drop unique index
    drop unique_index(:enrollments_context_roles, [:enrollment_id, :context_role_id])

    create index(:enrollments_context_roles, [:enrollment_id, :context_role_id])
  end
end
