defmodule Oli.Repo.Migrations.AddStatusToActivityRegistrationProjects do
  use Ecto.Migration

  # See: https://github.com/fly-apps/safe-ecto-migrations#adding-a-column-with-a-default-value
  # For large tables, adding a column with a default or backfilling in the same migration can block writes.
  # This migration only adds the column as nullable, with no default, to avoid long locks.
  def change do
    alter table(:activity_registration_projects) do
      add :status, :string
    end
  end
end
