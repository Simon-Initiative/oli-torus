defmodule Oli.Repo.Migrations.AttemptStates do
  use Ecto.Migration

  def change do
    alter table(:part_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
      add :grading_approach, :string, default: "automatic", null: false
    end

    alter table(:activity_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
    end

    alter table(:resource_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
    end

    flush()

    execute "UPDATE part_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE part_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE activity_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE activity_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE resource_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE resource_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE part_attempts SET grading_approach = 'automatic';"
    execute "UPDATE part_attempts SET date_submitted = date_evaluated;"
    execute "UPDATE activity_attempts SET date_submitted = date_evaluated;"
    execute "UPDATE resource_attempts SET date_submitted = date_evaluated;"

    flush()
  end

end
