defmodule Oli.Repo.Migrations.DeadlineManagement do
  use Ecto.Migration

  def up do
    alter table(:resource_attempts) do
      add :was_late, :boolean, default: false, null: false
      add :auto_submit_job_id, :integer
    end
    alter table(:resource_accesses) do
      add :was_late, :boolean, default: false, null: false
    end
  end

  def down do
    alter table(:resource_attempts) do
      remove :was_late, :boolean
      remove :auto_submit_job_id, :boolean
    end
    alter table(:resource_accesses) do
      remove :was_late, :boolean
    end
  end
end
