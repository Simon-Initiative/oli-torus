defmodule Oli.Clickhouse.AdminOperations do
  @moduledoc """
  Safe admin-only ClickHouse operations exposed in the analytics dashboard.
  """

  alias Oli.Accounts.Author
  alias Oli.Auditing
  alias Oli.FeatureTelemetry
  alias Oli.Utils.Appsignal
  alias Phoenix.PubSub

  @pubsub_topic "clickhouse_admin_operations"
  @allowed_kinds [:setup, :migrate_up, :migrate_down]
  @audit_initiated :clickhouse_admin_operation_initiated
  @spec allowed_kinds() :: [atom()]
  def allowed_kinds, do: @allowed_kinds

  @spec topic() :: String.t()
  def topic, do: @pubsub_topic

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: PubSub.subscribe(Oli.PubSub, @pubsub_topic)

  @spec start(atom(), Author.t() | nil) :: {:ok, map()} | {:error, term()}
  def start(kind, %Author{} = author) when kind in @allowed_kinds do
    with {:ok, capabilities} <- analytics_module().admin_capabilities(),
         {:ok, _} <- validate_capabilities(kind, capabilities) do
      operation = new_operation(kind, author, capabilities)
      record_audit(author, operation)
      broadcast({:clickhouse_admin_operation_started, operation})

      case execution_mode() do
        :sync ->
          _ = execute_operation(operation)

        _ ->
          Task.start(fn -> execute_operation(operation) end)
      end

      {:ok, operation}
    end
  end

  def start(kind, _author) when kind in @allowed_kinds, do: {:error, :invalid_author}
  def start(_kind, _author), do: {:error, :unsupported_operation}

  defp execute_operation(operation) do
    action = Atom.to_string(operation.kind)

    FeatureTelemetry.span(
      :clickhouse_admin_operations,
      "phase_4",
      action,
      fn ->
        sink = &handle_task_event(operation, &1)

        result =
          try do
            case task_module().run(operation.kind, sink: sink) do
              :ok -> :ok
              {:ok, _} = ok -> ok
              other -> {:error, other}
            end
          rescue
            exception ->
              {:error, Exception.message(exception)}
          end

        finalize_operation(operation, result)
      end,
      %{kind: action, operation_id: operation.id}
    )
  end

  defp finalize_operation(operation, :ok), do: complete_operation(operation, nil)

  defp finalize_operation(operation, {:ok, _}),
    do: complete_operation(operation, nil)

  defp finalize_operation(operation, {:error, reason}),
    do: fail_operation(operation, reason)

  defp complete_operation(operation, error) do
    completed_operation =
      operation
      |> Map.put(:status, :completed)
      |> Map.put(:error, error)
      |> Map.put(:finished_at, DateTime.utc_now())
      |> append_event(event("success", "Operation completed successfully."))

    emit_telemetry(:complete, completed_operation.kind, completed_operation, %{})
    broadcast({:clickhouse_admin_operation_finished, completed_operation})
    :ok
  end

  defp fail_operation(operation, reason) do
    message = normalize_reason(reason)

    failed_operation =
      operation
      |> Map.put(:status, :failed)
      |> Map.put(:error, message)
      |> Map.put(:finished_at, DateTime.utc_now())
      |> append_event(event("error", "Operation failed.", %{"reason" => message}))

    emit_telemetry(:failure, failed_operation.kind, failed_operation, %{reason: message})

    Appsignal.capture_error("ClickHouse admin operation failed", %{
      kind: failed_operation.kind,
      error: message
    })

    broadcast({:clickhouse_admin_operation_finished, failed_operation})
    {:error, message}
  end

  defp handle_task_event(operation, %{message: _message} = task_event) do
    event_entry =
      event(
        Map.get(task_event, :level, "info"),
        Map.get(task_event, :message),
        normalize_metadata(Map.get(task_event, :metadata, %{}))
      )

    emit_telemetry(:progress, operation.kind, operation, Map.get(task_event, :metadata, %{}))

    broadcast(
      {:clickhouse_admin_operation_progress, %{operation_id: operation.id, event: event_entry}}
    )

    :ok
  end

  defp validate_capabilities(:setup, %{setup_enabled: true}), do: {:ok, :allowed}
  defp validate_capabilities(:setup, _), do: {:error, :setup_not_available}

  defp validate_capabilities(:migrate_up, %{migrate_up_enabled: true}), do: {:ok, :allowed}

  defp validate_capabilities(:migrate_up, %{reachable: true}),
    do: {:error, :migrate_up_not_available}

  defp validate_capabilities(kind, %{reachable: true}) when kind in [:migrate_down],
    do: {:ok, :allowed}

  defp validate_capabilities(kind, _capabilities) when kind in [:migrate_up, :migrate_down],
    do: {:error, :clickhouse_unreachable}

  defp new_operation(kind, author, capabilities) do
    %{
      id: Ecto.UUID.generate(),
      kind: kind,
      operation_label: operation_label(kind),
      status: :running,
      error: nil,
      started_at: DateTime.utc_now(),
      finished_at: nil,
      events: [event("info", operation_label(kind) <> " requested.")],
      metadata: %{"capabilities" => capabilities},
      initiated_by_id: author.id,
      actor_name: actor_name(author)
    }
  end

  defp record_audit(author, operation) do
    Auditing.log_admin_action(author, @audit_initiated, nil, %{
      "operation_id" => operation.id,
      "kind" => Atom.to_string(operation.kind),
      "operation_label" => operation.operation_label,
      "message" => "#{operation.operation_label} requested.",
      "actor_name" => operation.actor_name
    })
  end

  defp append_event(operation, event_entry) do
    Map.update!(operation, :events, fn events -> events ++ [event_entry] end)
  end

  defp event(level, message, metadata \\ %{}) do
    %{
      "ts" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "level" => normalize_level(level),
      "message" => message,
      "metadata" => normalize_metadata(metadata)
    }
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(metadata) when is_list(metadata), do: Map.new(metadata)
  defp normalize_metadata(_), do: %{}

  defp normalize_level(level) when is_atom(level), do: Atom.to_string(level)
  defp normalize_level(level) when is_binary(level), do: level
  defp normalize_level(level), do: to_string(level)

  defp normalize_reason(reason) when is_binary(reason), do: reason
  defp normalize_reason(reason), do: inspect(reason)

  defp actor_name(author) do
    author.name || author.email || "Author ##{author.id}"
  end

  defp operation_label(:setup), do: "Setup database"
  defp operation_label(:migrate_up), do: "Migrate up"
  defp operation_label(:migrate_down), do: "Migrate down"

  defp broadcast(message), do: PubSub.broadcast(Oli.PubSub, @pubsub_topic, message)

  defp emit_telemetry(event, kind, operation, extra) do
    :telemetry.execute(
      [:oli, :clickhouse, :admin_operation, event],
      %{count: 1},
      %{
        kind: Atom.to_string(kind),
        operation_id: operation.id,
        status: operation.status && Atom.to_string(operation.status)
      }
      |> Map.merge(normalize_metadata(extra))
    )
  end

  defp execution_mode do
    Application.get_env(:oli, :clickhouse_admin_operations_mode, :async)
  end

  defp task_module do
    Application.get_env(:oli, :clickhouse_tasks_module, Oli.Clickhouse.Tasks)
  end

  defp analytics_module do
    Application.get_env(
      :oli,
      :clickhouse_admin_analytics_module,
      Oli.Analytics.ClickhouseAnalytics
    )
  end
end
