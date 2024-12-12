defmodule Oli.Analytics.Datasets.Test do
  alias DigitalToken.Data
  use Oli.DataCase

  alias Oli.Analytics.Datasets.BrowseJobOptions

  alias Oli.Analytics.Datasets
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.EmrServerless
  alias Oli.Analytics.Datasets.JobConfig
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Repo.{Paging, Sorting}

  def job(attrs) do
    template = %DatasetJob{
      application_id: "application_id",
      job_id: "job_id",
      job_run_id: "job_run_id",
      job_type: :custom,
      output_type: :csv,
      status: :pending,
      finished_on: nil,
      configuration: %JobConfig{
        section_ids: [],
        chunk_size: 10_000,
        event_type: "attempt_e",
        event_sub_types: [],
        ignored_student_ids: [],
        excluded_fields: []
      }
    }

    {:ok, _} = DatasetJob.changeset(template, attrs)
    |> Repo.insert()
  end

  describe "browse jobs" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "browse basics", %{project: project, author: author1, author2: author2} do

      job(%{status: :pending, job_id: "job_id_1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      job(%{status: :running, job_id: "job_id_2", project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      job(%{status: :running, job_id: "job_id_3", project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      job(%{status: :failed, job_id: "job_id_4", project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, job_type: nil}
      )

      assert length(result) == 4

      # filter by job type
      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, job_type: :custom}
      )
      assert length(result) == 3

      # filter by initiator
      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, initiated_by_id: author1.id}
      )
      assert length(result) == 3

      # filter by initiator AND job type
      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, job_type: :datashop, initiated_by_id: author1.id}
      )
      assert length(result) == 1

      # filter by statuses
      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, statuses: [:pending, :running]}
      )
      assert length(result) == 3

      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id, statuses: [:pending]}
      )
      assert length(result) == 1

      # filter by project
      result = Datasets.browse_jobs(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :job_id, direction: :desc},
        %BrowseJobOptions{project_id: project.id + 1}
      )
      assert length(result) == 0

    end
  end

end
