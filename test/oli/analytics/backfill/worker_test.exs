defmodule Oli.Analytics.Backfill.WorkerTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.Worker
  alias Oli.Repo

  defmodule DryRunAnalytics do
    def execute_query(_query, _desc, _opts) do
      body = ~s({"data":[{"total_rows":"5","total_bytes":"250"}]})

      {:ok,
       %{
         body: body,
         parsed_body: %{"data" => [%{"total_rows" => "5", "total_bytes" => "250"}]},
         execution_time_ms: 12.5
       }}
    end

    def query_status(_query_id), do: {:ok, %{status: :completed}}
  end

  defmodule InsertAnalytics do
    def execute_query(_query, _desc, _opts) do
      {:ok, %{body: "", execution_time_ms: 80.0}}
    end

    def query_status(_query_id) do
      {:ok,
       %{
         status: :completed,
         rows_read: 1_000,
         rows_written: 980,
         bytes_read: 65_536,
         bytes_written: 32_768,
         query_duration_ms: 4_200
       }}
    end
  end

  defmodule ErrorAnalytics do
    def execute_query(_query, _desc, _opts), do: {:error, "boom"}
    def query_status(_query_id), do: {:error, :not_called}
  end

  setup do
    original = %{
      aws_access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      aws_secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      aws_s3_access_key_id: System.get_env("AWS_S3_ACCESS_KEY_ID"),
      aws_s3_secret_access_key: System.get_env("AWS_S3_SECRET_ACCESS_KEY"),
      analytics_module: Application.get_env(:oli, :clickhouse_analytics_module)
    }

    System.put_env("AWS_ACCESS_KEY_ID", "test-key")
    System.put_env("AWS_SECRET_ACCESS_KEY", "test-secret")
    System.put_env("AWS_S3_ACCESS_KEY_ID", "test-key")
    System.put_env("AWS_S3_SECRET_ACCESS_KEY", "test-secret")

    on_exit(fn ->
      Enum.each(original, fn
        {:analytics_module, module} ->
          if module do
            Application.put_env(:oli, :clickhouse_analytics_module, module)
          else
            Application.delete_env(:oli, :clickhouse_analytics_module)
          end

        {:aws_access_key_id, nil} ->
          System.delete_env("AWS_ACCESS_KEY_ID")

        {:aws_secret_access_key, nil} ->
          System.delete_env("AWS_SECRET_ACCESS_KEY")

        {:aws_s3_access_key_id, nil} ->
          System.delete_env("AWS_S3_ACCESS_KEY_ID")

        {:aws_s3_secret_access_key, nil} ->
          System.delete_env("AWS_S3_SECRET_ACCESS_KEY")

        {:aws_access_key_id, value} ->
          System.put_env("AWS_ACCESS_KEY_ID", value)

        {:aws_secret_access_key, value} ->
          System.put_env("AWS_SECRET_ACCESS_KEY", value)

        {:aws_s3_access_key_id, value} ->
          System.put_env("AWS_S3_ACCESS_KEY_ID", value)

        {:aws_s3_secret_access_key, value} ->
          System.put_env("AWS_S3_SECRET_ACCESS_KEY", value)
      end)
    end)

    :ok
  end

  describe "perform/1" do
    test "completes dry run and stores metrics" do
      Application.put_env(:oli, :clickhouse_analytics_module, DryRunAnalytics)

      run = insert_run(%{dry_run: true})

      assert :ok = Worker.perform(%Oban.Job{args: %{"run_id" => run.id}})

      run = Repo.get!(BackfillRun, run.id)
      assert run.status == :completed
      assert run.rows_read == 5
      assert run.rows_written == 0
      assert run.bytes_read == 250
      assert run.metadata["dry_run"]
      assert run.finished_at != nil
    end

    test "completes insert run and captures query status metrics" do
      Application.put_env(:oli, :clickhouse_analytics_module, InsertAnalytics)

      run = insert_run(%{dry_run: false})

      assert :ok = Worker.perform(%Oban.Job{args: %{"run_id" => run.id}})

      run = Repo.get!(BackfillRun, run.id)
      assert run.status == :completed
      assert run.rows_read == 1_000
      assert run.rows_written == 980
      assert run.bytes_read == 65_536
      assert run.bytes_written == 32_768
      assert run.duration_ms == 4_200
      assert %{"query_id" => _} = run.metadata
    end

    test "marks run as failed when ClickHouse returns an error" do
      Application.put_env(:oli, :clickhouse_analytics_module, ErrorAnalytics)

      run = insert_run(%{dry_run: false})

      assert {:error, _} = Worker.perform(%Oban.Job{args: %{"run_id" => run.id}})

      run = Repo.get!(BackfillRun, run.id)
      assert run.status == :failed
      assert run.error =~ "boom"
      refute run.finished_at == nil
    end
  end

  defp insert_run(attrs) do
    defaults = %{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONAsString",
      options: %{},
      clickhouse_settings: %{},
      dry_run: false
    }

    attrs = Map.merge(defaults, attrs)

    %BackfillRun{}
    |> BackfillRun.creation_changeset(attrs)
    |> Repo.insert!()
  end
end
