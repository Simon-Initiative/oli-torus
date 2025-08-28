defmodule Oli.Repo.Migrations.CreateAuditLogEvents do
  use Ecto.Migration

  def change do
    create table(:audit_log_events) do
      add :user_id, :integer
      add :author_id, :integer
      add :event_type, :string, null: false
      add :section_id, :integer
      add :project_id, :integer
      add :resource_id, :integer
      add :details, :map, default: %{}

      timestamps(updated_at: false)
    end

    create index(:audit_log_events, [:user_id])
    create index(:audit_log_events, [:author_id])
    create index(:audit_log_events, [:section_id])
    create index(:audit_log_events, [:project_id])
    create index(:audit_log_events, [:event_type])
    create index(:audit_log_events, [:inserted_at])
  end
end
