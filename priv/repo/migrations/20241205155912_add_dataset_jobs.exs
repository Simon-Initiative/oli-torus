defmodule Oli.Repo.Migrations.AddDatasetJobs do
  use Ecto.Migration

  def change do
    create table(:dataset_jobs) do
      add :initiated_by_id, references(:authors)
      add :project_id, references(:projects)

      add :application_id, :string, null: true
      add :job_id, :string, null: false
      add :job_run_id, :string, null: true
      add :job_type, :string, null: false, default: "datashop"
      add :output_type, :string, null: false, default: "csv"

      # Runtime status information
      add :status, :string, null: false, default: "pending"
      add :finished_on, :utc_datetime

      add :configuration, :map, null: false

      timestamps(type: :timestamptz)
    end

    create index(:dataset_jobs, [:project_id])
  end
end
