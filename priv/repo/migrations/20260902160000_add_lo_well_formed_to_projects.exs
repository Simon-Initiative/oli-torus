defmodule Oli.Repo.Migrations.AddLoWellFormedToProjects do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:projects) do
      add :lo_well_formed, :boolean
    end

    execute("ALTER TABLE projects ALTER COLUMN lo_well_formed SET DEFAULT TRUE")
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:projects) do
      remove :lo_well_formed
    end
  end
end
