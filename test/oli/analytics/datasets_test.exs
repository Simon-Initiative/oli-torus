defmodule Oli.Analytics.Datasets.Test do
  use ExUnit.Case, async: true

  alias Oli.Analytics.Datasets
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.JobConfig

  test "testing applications list" do
    {:ok, app_id} = Datasets.determine_application_id()

    dataset_job = %Datasets.DatasetJob{
      application_id: app_id,
      job_id: "12a346993",
      job_type: :custom,
      output_type: :csv,
      status: nil,
      total_chunks: 0,
      completed_chunks: 0,
      initiated_on: DateTime.utc_now(),
      started_on: nil,
      finished_on: nil,
      initiated_by_id: 1,
      project_id: 1,
      configuration: %JobConfig{
        section_ids: [1922],
        chunk_size: 10_000,
        event_type: "attempt_evaluated",
        event_sub_types: ["part_attempt_evaluated"],
        ignored_student_ids: [1],
        excluded_fields: []
      }
    }

    Datasets.submit_job(dataset_job)

  end
end
