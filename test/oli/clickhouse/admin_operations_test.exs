defmodule Oli.Clickhouse.AdminOperationsTest do
  use Oli.DataCase, async: false

  alias Oli.Auditing.LogEvent
  alias Oli.Clickhouse.AdminOperations
  alias Oli.Accounts.SystemRole

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

  defmodule BlockingTasks do
    def run(kind, _opts) do
      test_pid = :persistent_term.get({__MODULE__, :test_pid})
      send(test_pid, {:admin_operation_started, kind, self()})

      receive do
        :release_blocking_task -> :ok
      end
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

  test "captures a single initiation audit event" do
    author = admin_author()

    assert {:ok, operation} = AdminOperations.start(:setup, author)

    events =
      LogEvent
      |> Repo.all()
      |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})

    assert Enum.map(events, & &1.event_type) == [:clickhouse_admin_operation_initiated]

    assert Enum.all?(events, &(get_in(&1.details, ["operation_id"]) == operation.id))
    [event] = events
    assert event.author_id == author.id
    assert event.details["kind"] == "setup"
    assert event.details["operation_label"] == "Setup database"
    assert event.details["message"] == "Setup database requested."
  end

  test "rejects setup when initialization is not available" do
    Application.put_env(:oli, :clickhouse_admin_analytics_module, FakeAnalyticsInitialized)
    author = admin_author()

    assert {:error, :setup_not_available} = AdminOperations.start(:setup, author)
  end

  test "rejects unauthorized authors" do
    author = author_fixture()

    assert {:error, :unauthorized} = AdminOperations.start(:setup, author)
    assert Repo.aggregate(LogEvent, :count, :id) == 0
  end

  test "rejects concurrent admin operations while one is running" do
    Application.put_env(:oli, :clickhouse_tasks_module, BlockingTasks)
    Application.put_env(:oli, :clickhouse_admin_operations_mode, :async)
    :persistent_term.put({BlockingTasks, :test_pid}, self())

    on_exit(fn -> :persistent_term.erase({BlockingTasks, :test_pid}) end)

    author = admin_author()

    assert {:ok, _operation} = AdminOperations.start(:setup, author)
    assert_receive {:admin_operation_started, :setup, task_pid}

    assert {:error, :operation_in_progress} = AdminOperations.start(:migrate_up, author)

    send(task_pid, :release_blocking_task)
  end

  defp admin_author do
    author_fixture(%{system_role_id: SystemRole.role_id().system_admin})
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)
end
