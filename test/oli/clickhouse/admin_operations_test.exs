defmodule Oli.Clickhouse.AdminOperationsTest do
  use Oli.DataCase, async: false

  alias Oli.Auditing.LogEvent
  alias Oli.Clickhouse.AdminOperations

  defmodule FakeAnalytics do
    def admin_capabilities do
      {:ok,
       %{
         reachable: true,
         database_exists: false,
         initialized: false,
         setup_enabled: true,
         allowed_operations: [:setup, :migrate_up, :migrate_down]
       }}
    end
  end

  defmodule FakeAnalyticsInitialized do
    def admin_capabilities do
      {:ok,
       %{
         reachable: true,
         database_exists: true,
         initialized: true,
         setup_enabled: false,
         allowed_operations: [:migrate_up, :migrate_down]
       }}
    end
  end

  defmodule FakeTasks do
    def run(kind, opts) do
      sink = Keyword.fetch!(opts, :sink)
      sink.(%{level: :info, message: "#{kind} started", metadata: %{step: "start"}})
      sink.(%{level: :info, message: "#{kind} finished", metadata: %{step: "finish"}})
      :ok
    end
  end

  setup do
    original_tasks = Application.get_env(:oli, :clickhouse_tasks_module)
    original_analytics = Application.get_env(:oli, :clickhouse_admin_analytics_module)
    original_mode = Application.get_env(:oli, :clickhouse_admin_operations_mode)

    Application.put_env(:oli, :clickhouse_tasks_module, FakeTasks)
    Application.put_env(:oli, :clickhouse_admin_analytics_module, FakeAnalytics)
    Application.put_env(:oli, :clickhouse_admin_operations_mode, :sync)

    Repo.delete_all(LogEvent)

    on_exit(fn ->
      restore_env(:clickhouse_tasks_module, original_tasks)
      restore_env(:clickhouse_admin_analytics_module, original_analytics)
      restore_env(:clickhouse_admin_operations_mode, original_mode)
    end)

    :ok
  end

  test "captures a single initiation audit event and lists initiation history" do
    author = author_fixture()

    assert {:ok, operation} = AdminOperations.start(:setup, author)

    events =
      LogEvent
      |> Repo.all()
      |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})

    assert Enum.map(events, & &1.event_type) == [:clickhouse_admin_operation_initiated]

    assert Enum.all?(events, &(get_in(&1.details, ["operation_id"]) == operation.id))

    [history] = AdminOperations.list_operations(limit: 10)
    assert history.id == operation.id
    assert history.kind == :setup
    assert history.status == :initiated
    refute history.finished_at
    assert Enum.any?(history.events, &(&1["message"] == "Initialize database requested."))
  end

  test "rejects setup when initialization is not available" do
    Application.put_env(:oli, :clickhouse_admin_analytics_module, FakeAnalyticsInitialized)
    author = author_fixture()

    assert {:error, :setup_not_available} = AdminOperations.start(:setup, author)
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)
end
