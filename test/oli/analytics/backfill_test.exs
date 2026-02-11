defmodule Oli.Analytics.BackfillTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Oli.Utils.Seeder.AccountsFixtures

  alias Oli.Accounts.SystemRole
  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun

  defmodule FakeAnalyticsRunning do
    def raw_events_table, do: "analytics.raw_events"

    def query_progress("running-query") do
      {:ok,
       %{
         status: :running,
         read_rows: 50,
         read_bytes: 1_000,
         written_rows: 0,
         written_bytes: 0,
         memory_usage: 1_024,
         elapsed_ms: 5_000.0,
         total_rows: 200,
         total_rows_approx: 200,
         total_bytes: 4_000,
         total_bytes_approx: 4_000
       }}
    end

    def query_progress(_), do: {:ok, :none}

    def query_status("running-query"), do: {:ok, %{status: :running}}
    def query_status(_), do: {:ok, %{status: :running}}
  end

  defmodule FakeAnalyticsCompleted do
    def raw_events_table, do: "analytics.raw_events"

    def query_progress(_), do: {:ok, :none}

    def query_status("completed-query") do
      {:ok,
       %{
         status: :completed,
         rows_read: 9_445,
         rows_written: 0,
         bytes_read: 12_351_076,
         bytes_written: 0,
         query_duration_ms: 11_295,
         memory_usage: 35_125_627
       }}
    end

    def query_status(_), do: {:ok, %{status: :running}}
  end

  setup do
    original = Application.get_env(:oli, :clickhouse_analytics_module)

    on_exit(fn ->
      Application.put_env(:oli, :clickhouse_analytics_module, original)
    end)

    :ok
  end

  describe "schedule_backfill/2" do
    test "creates a run and enqueues a worker job" do
      admin =
        author_fixture(%{
          system_role_id: SystemRole.role_id().system_admin
        })

      attrs = %{
        s3_pattern: "s3://example-bucket/**/*.jsonl",
        target_table: "analytics.raw_events",
        format: "JSONAsString",
        dry_run: true
      }

      assert {:ok, %BackfillRun{} = run} = Backfill.schedule_backfill(attrs, admin)
      assert run.initiated_by_id == admin.id
      assert run.status == :pending
      assert run.target_table == "analytics.raw_events"

      assert_enqueued(
        worker: Oli.Analytics.Backfill.Worker,
        args: %{"run_id" => run.id}
      )
    end

    test "returns changeset errors when attributes are invalid" do
      admin =
        author_fixture(%{
          system_role_id: SystemRole.role_id().system_admin
        })

      assert {:error, %Ecto.Changeset{} = changeset} = Backfill.schedule_backfill(%{}, admin)
      assert %{s3_pattern: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "refresh_running_runs/0" do
    test "updates progress for running queries" do
      Application.put_env(:oli, :clickhouse_analytics_module, FakeAnalyticsRunning)

      assert Application.get_env(:oli, :clickhouse_analytics_module) == FakeAnalyticsRunning

      run =
        %BackfillRun{
          target_table: "analytics.raw_events",
          s3_pattern: "s3://bucket/path/**/*.jsonl",
          format: "JSONAsString",
          status: :running,
          dry_run: true,
          query_id: "running-query"
        }
        |> Oli.Repo.insert!()

      :ok = Backfill.refresh_running_runs()

      run = Oli.Repo.get!(BackfillRun, run.id)
      assert run.status == :running

      progress = run.metadata["progress"] || %{}
      assert progress["read_rows"] == 50
      assert progress["percent"] == 25.0
    end

    test "marks finished queries as completed" do
      Application.put_env(:oli, :clickhouse_analytics_module, FakeAnalyticsCompleted)

      run =
        %BackfillRun{
          target_table: "analytics.raw_events",
          s3_pattern: "s3://bucket/path/**/*.jsonl",
          format: "JSONAsString",
          status: :running,
          dry_run: true,
          query_id: "completed-query"
        }
        |> Oli.Repo.insert!()

      :ok = Backfill.refresh_running_runs()

      run = Oli.Repo.get!(BackfillRun, run.id)
      assert run.status == :completed
      assert run.rows_read == 9_445
      assert run.bytes_read == 12_351_076
      assert run.duration_ms == 11_295

      status_metadata = run.metadata["query_status"] || %{}
      assert status_metadata["status"] in [:completed, "completed"]
    end
  end
end
