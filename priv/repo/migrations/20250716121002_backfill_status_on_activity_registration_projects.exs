defmodule Oli.Repo.Migrations.BackfillStatusOnActivityRegistrationProjects do
  use Ecto.Migration

  # See: https://github.com/fly-apps/safe-ecto-migrations#adding-a-column-with-a-default-value
  # This migration backfills the new status column. Splitting this from the column addition avoids long locks.
  def up do
    execute "UPDATE activity_registration_projects SET status = 'enabled' WHERE status IS NULL"
  end

  def down do
    execute "UPDATE activity_registration_projects SET status = NULL WHERE status = 'enabled'"
  end
end
