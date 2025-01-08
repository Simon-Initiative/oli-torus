defmodule Oli.Analytics.Datasets.Test do

  use Oli.DataCase

  alias Oli.Analytics.Datasets.BrowseJobOptions

  alias Oli.Analytics.Datasets
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.JobConfig
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Test.MockHTTP
  import Mox

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

  describe "update job statuses" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "multiple jobs, but all from same application id", %{project: project, author: author1, author2: author2} do

      {:ok, %{id: id1} = job1} = job(%{status: :pending, job_id: "job_id_1", job_run_id: "1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      {:ok, %{id: id2} = job2} = job(%{status: :running, job_id: "job_id_2", job_run_id: "2",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, %{id: id3} = job3} = job(%{status: :running, job_id: "job_id_3", job_run_id: "3",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, job4} = job(%{status: :failed, job_id: "job_id_4", job_run_id: "4",project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      MockHTTP
      |> expect(:get, fn _, _ ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
                "jobRuns" => [
                  %{
                    "id" => "1",
                    "state"=> "RUNNING"
                  },
                  %{
                    "id" => "2",
                    "state" => "FAILED"
                  },
                  %{
                    "id" => "3",
                    "state" => "SUCCESS"
                  },
                  %{
                    "id" => "4",
                    "state" => "FAILED"
                  }
                ]
             })
         }}
      end)

      {:ok, status_changed} = Datasets.update_job_statuses()
      assert Enum.count(status_changed) == 3
      assert [{^id1, :running}, {^id2, :failed}, {^id3, :success}] = status_changed

      # Read the jobs again from the DB to make sure the statuses have been updated
      job1 = Repo.get(DatasetJob, job1.id)
      assert job1.status == :running
      assert job1.finished_on == nil

      job2 = Repo.get(DatasetJob, job2.id)
      assert job2.status == :failed
      assert job2.finished_on != nil

      job3 = Repo.get(DatasetJob, job3.id)
      assert job3.status == :success
      assert job3.finished_on != nil

      # this one hasn't changed status
      job4 = Repo.get(DatasetJob, job4.id)
      assert job4.status == :failed
      assert job4.finished_on == nil

    end

    test "multiple jobs, and multiple application ids", %{project: project, author: author1, author2: author2} do

      {:ok, %{id: id1} = job1} = job(%{application_id: "ONE", status: :pending, job_id: "job_id_1", job_run_id: "1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      {:ok, %{id: id2} = job2} = job(%{application_id: "TWO", status: :running, job_id: "job_id_2", job_run_id: "2",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, %{id: id3} = job3} = job(%{application_id: "TWO", status: :running, job_id: "job_id_3", job_run_id: "3",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, job4} = job(%{application_id: "TWO", status: :failed, job_id: "job_id_4", job_run_id: "4",project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      # Mock out 2 different requests, one for each application id
      MockHTTP
      |> expect(:get, 2, fn url, _ ->

        body = if String.contains?(url, "ONE") do
          Jason.encode!(%{
            "jobRuns" => [
              %{
                "id" => "1",
                "state"=> "RUNNING"
              }
            ]
         })
        else
          Jason.encode!(%{
            "jobRuns" => [
              %{
                "id" => "2",
                "state" => "FAILED"
              },
              %{
                "id" => "3",
                "state" => "SUCCESS"
              },
              %{
                "id" => "4",
                "state" => "FAILED"
              }
            ]
         })
        end

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: body
         }}
      end)

      {:ok, status_changed} = Datasets.update_job_statuses()

      assert Enum.count(status_changed) == 3

      # sort the list of tuples by the job id
      status_changed = Enum.sort(status_changed)

      assert [{^id1, :running}, {^id2, :failed}, {^id3, :success}] = status_changed

      # Read the jobs again from the DB to make sure the statuses have been updated

      # this one hasn't changed status
      job1 = Repo.get(DatasetJob, job1.id)
      assert job1.status == :running

      job2 = Repo.get(DatasetJob, job2.id)
      assert job2.status == :failed

      job3 = Repo.get(DatasetJob, job3.id)
      assert job3.status == :success

      job4 = Repo.get(DatasetJob, job4.id)
      assert job4.status == :failed

    end

    test "multiple jobs, and multiple application ids WITH FAILURE", %{project: project, author: author1, author2: author2} do

      {:ok, %{id: id1} = job1} = job(%{application_id: "ONE", status: :pending, job_id: "job_id_1", job_run_id: "1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      {:ok, job2} = job(%{application_id: "TWO", status: :running, job_id: "job_id_2", job_run_id: "2",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, job3} = job(%{application_id: "TWO", status: :running, job_id: "job_id_3", job_run_id: "3",project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      {:ok, job4} = job(%{application_id: "TWO", status: :failed, job_id: "job_id_4", job_run_id: "4",project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      # Mock out 2 different requests, one for each application id,
      # but with the second request failing
      MockHTTP
      |> expect(:get, 2, fn url, _ ->

        if String.contains?(url, "ONE") do

          {:ok, %HTTPoison.Response{
            status_code: 200,
            body: Jason.encode!(%{
              "jobRuns" => [
                %{
                  "id" => "1",
                  "state"=> "RUNNING"
                }
              ]
            })
          }}
        else
          {:error, :timeout}
        end
      end)

      {:ok, status_changed} = Datasets.update_job_statuses()

      assert Enum.count(status_changed) == 1
      assert [{^id1, :running}] = status_changed

      # Read the jobs again from the DB to make sure the statuses have been updated

      job1 = Repo.get(DatasetJob, job1.id)
      assert job1.status == :running

      job2 = Repo.get(DatasetJob, job2.id)
      assert job2.status == :running

      job3 = Repo.get(DatasetJob, job3.id)
      assert job3.status == :running

      job4 = Repo.get(DatasetJob, job4.id)
      assert job4.status == :failed

    end

    test "misalignment between jobs in DB and jobs in EMR", %{project: project, author: author1} do

      {:ok, job1} = job(%{status: :pending, job_id: "job_id_1", job_run_id: "1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})

      MockHTTP
      |> expect(:get, fn _, _ ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
                "jobRuns" => [
                  %{
                    "id" => "2",
                    "state"=> "RUNNING"
                  }
                ]
             })
         }}
      end)

      {:ok, []} = Datasets.update_job_statuses()

      # Read the job again from the DB to make sure the status hasn't been updated
      job1 = Repo.get(DatasetJob, job1.id)
      assert job1.status == :pending


    end
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

  describe "values retrieval" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "project values", %{project: project, author: author1, author2: author2} do

      job(%{status: :pending, job_id: "job_id_1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      job(%{status: :running, job_id: "job_id_2", project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      job(%{status: :running, job_id: "job_id_3", project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      job(%{status: :failed, job_id: "job_id_4", project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      result = Datasets.get_project_values()
      assert length(result) == 1
      assert result == [{project.id, project.title}]
    end

    test "initiator values", %{project: project, author: author1, author2: author2} do

      job(%{status: :pending, job_id: "job_id_1", project_id: project.id, initiated_by_id: author1.id, job_type: :datashop})
      job(%{status: :running, job_id: "job_id_2", project_id: project.id, initiated_by_id: author1.id, job_type: :custom})
      job(%{status: :running, job_id: "job_id_3", project_id: project.id, initiated_by_id: author2.id, job_type: :custom})
      job(%{status: :failed, job_id: "job_id_4", project_id: project.id, initiated_by_id: author2.id, job_type: :custom})

      result = Datasets.get_initiator_values()
      assert length(result) == 2
      result = Enum.sort(result)
      assert result == [{author1.id, author1.email}, {author2.id, author2.email}]
    end
  end

end
