defmodule Oli.Repo.Migrations.SetStatusNotNullAndDefaultOnActivityRegistrationProjects do
  use Ecto.Migration

  # See: https://github.com/fly-apps/safe-ecto-migrations#adding-a-column-with-a-default-value
  # This migration sets the status column to NOT NULL and adds a default, after backfilling.

  def up do
    alter table(:activity_registration_projects) do
      modify :status, :string, null: false, default: "enabled"
    end
  end

  def down do
    alter table(:activity_registration_projects) do
      modify :status, :string, null: true, default: nil
    end
  end
end
