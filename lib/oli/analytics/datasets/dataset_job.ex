defmodule Oli.Analytics.Datasets.DatasetJob do

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Analytics.Datasets.JobConfiguration

  @emr_statuses [
    :submitted,
    :pending,
    :scheduled,
    :running,
    :success,
    :failed,
    :cancelling,
    :cancelled,
    :queued
  ]

  schema "dataset_jobs" do
    belongs_to(:initiated_by, Oli.Accounts.Author)
    belongs_to(:project, Oli.Authoring.Course.Project)

    field(:application_id, :string)
    field(:job_id, :string)
    field(:job_run_id, :string)
    field(:job_type, Ecto.Enum, values: @emr_statuses, default: :submitted)
    field(:output_type, Ecto.Enum, values: [:csv, :parquet], default: :csv)

    # Runtime status information
    field(:status, Ecto.Enum, values: [:pending, :running, :cancelled, :finished], default: :pending)
    field(:total_chunks, :integer, default: 0)
    field(:completed_chunks, :integer, default: 0)

    field(:initiated_on, :utc_datetime)
    field(:started_on, :utc_datetime)
    field(:finished_on, :utc_datetime)

    # Embedded schema for job configuration
    embeds_one(:configuration, JobConfiguration, on_replace: :update)

    timestamps(type: :utc_datetime)

  end

  @doc false
  def changeset(dataset_job, attrs) do
    dataset_job
    |> cast(attrs, [
      :project_id,
      :initiated_by_id,
      :application_id,
      :job_id,
      :job_run_id,
      :job_type,
      :output_type,
      :status,
      :total_chunks,
      :completed_chunks,
      :initiated_on,
      :started_on,
      :finished_on
    ])
    |> cast_embed(:configuration, required: true)
    |> validate_required([
      :project_id,
      :initiated_by_id,
      :job_id,
      :job_type,
      :output_type
    ])
  end

end
