defmodule Oli.Repo.Migrations.AddLifecycleIndex do
  use Ecto.Migration

  def up do
    # Creates a partial index on the lifecycle_state column where the value is 'submitted'
    execute(
      "CREATE INDEX IF NOT EXISTS activity_attempts_submitted ON activity_attempts (lifecycle_state) WHERE lifecycle_state = 'submitted';"
    )
  end

  def down do
    execute("DROP INDEX activity_attempts_submitted;")
  end
end
