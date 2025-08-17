defmodule Oli.Repo.Migrations.CreateAgentTables do
  use Ecto.Migration

  def change do
    create table(:agent_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: true
      add :project_id, references(:projects, on_delete: :delete_all), null: true
      add :section_id, references(:sections, on_delete: :delete_all), null: true
      add :goal, :text, null: false
      add :run_type, :string, null: false
      add :status, :string, null: false, default: "running"
      add :plan, :jsonb
      add :context_summary, :text
      add :budgets, :jsonb
      add :model, :string
      add :cost_cents, :integer, default: 0
      add :tokens_in, :integer, default: 0
      add :tokens_out, :integer, default: 0
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create table(:agent_steps, primary_key: false) do
      add :run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all), null: false, primary_key: true
      add :step_num, :integer, null: false, primary_key: true
      add :phase, :string, null: false
      add :action, :jsonb
      add :observation, :jsonb
      add :rationale_summary, :text
      add :tokens_in, :integer
      add :tokens_out, :integer
      add :latency_ms, :integer
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create table(:agent_drafts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :object_type, :string, null: false
      add :object_ref, :string, null: false
      add :patch, :jsonb, null: false
      add :preview_html, :text
      add :status, :string, null: false, default: "pending"
      add :metadata, :jsonb
      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_runs, [:user_id])
    create index(:agent_runs, [:project_id])
    create index(:agent_runs, [:section_id])
    create index(:agent_runs, [:status])
    create index(:agent_runs, [:inserted_at])

    create index(:agent_steps, [:run_id])
    create index(:agent_steps, [:run_id, :step_num])

    create index(:agent_drafts, [:run_id])
    create index(:agent_drafts, [:status])

    # Foreign key constraints will be handled by the references() in the table definitions above
  end
end
