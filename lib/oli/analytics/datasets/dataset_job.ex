defmodule Oli.Analytics.Datasets.DatasetJob do

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Analytics.Datasets.JobConfig

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
    field(:job_type, Ecto.Enum, values: [:datashop, :custom], default: :custom)
    field(:output_type, Ecto.Enum, values: [:csv, :parquet], default: :csv)

    # Runtime status information
    field(:status, Ecto.Enum, values: @emr_statuses, default: :pending)
    field(:finished_on, :utc_datetime)

    # Embedded schema for job configuration
    embeds_one(:configuration, JobConfig, on_replace: :update)

    field(:project_title, :string, virtual: true)
    field(:total_count, :integer, virtual: true)
    field(:initiator_email, :string, virtual: true)

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
