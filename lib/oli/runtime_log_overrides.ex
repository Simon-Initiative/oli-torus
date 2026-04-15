defmodule Oli.RuntimeLogOverrides do
  @moduledoc """
  Runtime log override management for admin-applied system-level and module-level overrides.
  """

  require Logger

  alias Oli.RuntimeLogOverrides.Registry

  @default_timeout 5_000

  @type level :: Logger.level()
  @type override_state :: %{modules: list(map()), processes: list(map())}
  @type error_reason :: :invalid_level | :invalid_module

  @type node_state :: %{
          node: node(),
          system_level: level(),
          module_levels: %{optional(module()) => level()}
        }

  @type node_failure :: %{node: node(), reason: term()}

  @type cluster_state_summary :: %{
          status: :success | :partial | :failure,
          nodes: list(node_state()),
          read_errors: list(node_failure()),
          system_level: %{
            status: :uniform | :mixed,
            level: level() | nil,
            exceptions: list(map())
          },
          module_levels: list(map())
        }

  @type aggregate_result :: %{
          operation: :apply_system | :clear_system | :apply_module | :clear_module,
          requested_level: level() | nil,
          requested_module: module() | nil,
          target_nodes: list(node()),
          successful_nodes: list(node()),
          failed_nodes: list(node_failure()),
          status: :success | :partial | :failure,
          cluster_state: cluster_state_summary()
        }

  defmodule RPC do
    @moduledoc false

    def call(node, module, function, args, timeout) do
      :erpc.call(node, module, function, args, timeout)
    end
  end

  @spec list_overrides() :: override_state()
  def list_overrides do
    Registry.list_overrides()
  end

  @spec local_state() :: node_state()
  def local_state do
    %{
      node: node(),
      system_level: Logger.level(),
      module_levels:
        list_overrides().modules
        |> Enum.reduce(%{}, fn %{target: module, level: level}, acc ->
          Map.put(acc, module, level)
        end)
    }
  end

  @spec set_system_level(atom() | String.t()) :: {:ok, level()} | {:error, :invalid_level}
  def set_system_level(level) do
    with {:ok, validated_level} <- validate_level(level),
         %{system_level: applied_level} <- apply_system_level_local(validated_level) do
      {:ok, applied_level}
    end
  end

  @spec clear_system_level() :: {:ok, level()}
  def clear_system_level do
    %{system_level: cleared_level} = clear_system_level_local()
    {:ok, cleared_level}
  end

  @spec set_module_level(String.t(), atom() | String.t()) ::
          {:ok, override_state()} | {:error, error_reason()}
  def set_module_level(module_name, level) do
    with {:ok, module} <- parse_module(module_name),
         {:ok, validated_level} <- validate_level(level),
         %{module_levels: module_levels} <- apply_module_level_local(module, validated_level) do
      {:ok, overrides_from_module_levels(module_levels)}
    else
      {:error, _reason} = error ->
        log_failed_module_override("set", module_name, level, error)
        error
    end
  end

  @spec clear_module_level(String.t()) :: {:ok, override_state()} | {:error, :invalid_module}
  def clear_module_level(module_name) do
    with {:ok, module} <- parse_module(module_name),
         %{module_levels: module_levels} <- clear_module_level_local(module) do
      {:ok, overrides_from_module_levels(module_levels)}
    else
      {:error, _reason} = error ->
        log_failed_module_override("clear", module_name, nil, error)
        error
    end
  end

  @spec cluster_apply_system_level(atom() | String.t(), Keyword.t()) ::
          {:ok, aggregate_result()} | {:error, aggregate_result() | :invalid_level}
  def cluster_apply_system_level(level, opts \\ []) do
    opts = runtime_opts(opts)

    with {:ok, validated_level} <- validate_level(level) do
      cluster_operation(
        :apply_system,
        fn node, rpc_opts ->
          rpc_call(node, :apply_system_level_local, [validated_level], rpc_opts)
        end,
        validated_level,
        nil,
        opts
      )
    end
  end

  @spec cluster_clear_system_level(Keyword.t()) ::
          {:ok, aggregate_result()} | {:error, aggregate_result()}
  def cluster_clear_system_level(opts \\ []) do
    opts = runtime_opts(opts)

    cluster_operation(
      :clear_system,
      fn node, rpc_opts ->
        rpc_call(node, :clear_system_level_local, [], rpc_opts)
      end,
      nil,
      nil,
      opts
    )
  end

  @spec cluster_apply_module_level(String.t() | module(), atom() | String.t(), Keyword.t()) ::
          {:ok, aggregate_result()} | {:error, aggregate_result() | error_reason()}
  def cluster_apply_module_level(module_name, level, opts \\ []) do
    opts = runtime_opts(opts)

    with {:ok, module} <- normalize_module(module_name),
         {:ok, validated_level} <- validate_level(level) do
      cluster_operation(
        :apply_module,
        fn node, rpc_opts ->
          rpc_call(node, :apply_module_level_local, [module, validated_level], rpc_opts)
        end,
        validated_level,
        module,
        opts
      )
    end
  end

  @spec cluster_clear_module_level(String.t() | module(), Keyword.t()) ::
          {:ok, aggregate_result()} | {:error, aggregate_result() | :invalid_module}
  def cluster_clear_module_level(module_name, opts \\ []) do
    opts = runtime_opts(opts)

    with {:ok, module} <- normalize_module(module_name) do
      cluster_operation(
        :clear_module,
        fn node, rpc_opts ->
          rpc_call(node, :clear_module_level_local, [module], rpc_opts)
        end,
        nil,
        module,
        opts
      )
    end
  end

  @spec cluster_state(Keyword.t()) :: cluster_state_summary()
  def cluster_state(opts \\ []) do
    opts = runtime_opts(opts)
    nodes = target_nodes(opts)

    {states, errors} =
      nodes
      |> collect_node_results(opts, fn node, rpc_opts ->
        rpc_call(node, :local_state, [], rpc_opts)
      end)
      |> partition_node_results()

    %{
      status: classify_result(states, errors),
      nodes: states,
      read_errors: errors,
      system_level: summarize_system_levels(states),
      module_levels: summarize_module_levels(states)
    }
  end

  @spec apply_system_level_local(level()) :: node_state()
  def apply_system_level_local(level) when is_atom(level) do
    :ok = Logger.configure(level: level)

    Logger.info("Runtime system log level set level=#{level} node=#{node()}")

    local_state()
  end

  @spec clear_system_level_local() :: node_state()
  def clear_system_level_local do
    default_level = default_system_level()
    :ok = Logger.configure(level: default_level)

    Logger.info("Runtime system log level cleared level=#{default_level} node=#{node()}")

    local_state()
  end

  @spec apply_module_level_local(module(), level()) :: node_state()
  def apply_module_level_local(module, level) when is_atom(module) and is_atom(level) do
    :ok = Logger.put_module_level(module, level)
    {:ok, _override} = Registry.put_module_override(module, level)

    Logger.info(
      "Runtime log override set for module=#{inspect(module)} level=#{level} node=#{node()}"
    )

    local_state()
  end

  @spec clear_module_level_local(module()) :: node_state()
  def clear_module_level_local(module) when is_atom(module) do
    :ok = Logger.delete_module_level(module)
    :ok = Registry.delete_module_override(module)

    Logger.info("Runtime log override cleared for module=#{inspect(module)} node=#{node()}")

    local_state()
  end

  defp cluster_operation(operation, invoke_rpc, requested_level, requested_module, opts) do
    start = System.monotonic_time()
    nodes = target_nodes(opts)

    {successful_nodes, failed_nodes} =
      nodes
      |> collect_node_results(opts, invoke_rpc)
      |> Enum.reduce({[], []}, fn
        {node, {:ok, _state}}, {successes, failures} ->
          {[node | successes], failures}

        {node, {:error, reason}}, {successes, failures} ->
          {successes, [%{node: node, reason: summarize_reason(reason)} | failures]}
      end)

    cluster_state = cluster_state(opts)

    result = %{
      operation: operation,
      requested_level: requested_level,
      requested_module: requested_module,
      target_nodes: nodes,
      successful_nodes: Enum.reverse(successful_nodes),
      failed_nodes: Enum.reverse(failed_nodes),
      status: classify_result(successful_nodes, failed_nodes),
      cluster_state: cluster_state
    }

    duration = System.monotonic_time() - start
    emit_cluster_operation(result, duration)

    case result.status do
      :success -> {:ok, result}
      _ -> {:error, result}
    end
  end

  defp rpc_call(node, function, args, opts) do
    rpc_module = Keyword.get(opts, :rpc_module, RPC)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    try do
      result =
        if node == node() do
          apply(__MODULE__, function, args)
        else
          rpc_module.call(node, __MODULE__, function, args, timeout)
        end

      {:ok, result}
    rescue
      exception ->
        {:error, {:exception, exception, __STACKTRACE__}}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}

      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  defp runtime_opts(opts) do
    Keyword.merge(Application.get_env(:oli, :runtime_log_overrides, []), opts)
  end

  defp collect_node_results(nodes, opts, fun) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    nodes
    |> Task.async_stream(
      fn node -> {node, fun.(node, opts)} end,
      ordered: true,
      timeout: timeout + 100,
      on_timeout: :kill_task,
      max_concurrency: max(length(nodes), 1)
    )
    |> Enum.map(fn
      {:ok, result} ->
        result

      {:exit, reason} ->
        {nil, {:error, {:exit, reason}}}
    end)
    |> Enum.zip(nodes)
    |> Enum.map(fn {result, original_node} ->
      case result do
        {nil, {:error, reason}} -> {original_node, {:error, reason}}
        {node, node_result} -> {node, node_result}
      end
    end)
  end

  defp partition_node_results(results) do
    Enum.reduce(results, {[], []}, fn
      {_, {:ok, state}}, {states, errors} ->
        {[state | states], errors}

      {node, {:error, reason}}, {states, errors} ->
        {states, [%{node: node, reason: summarize_reason(reason)} | errors]}
    end)
    |> then(fn {states, errors} -> {Enum.reverse(states), Enum.reverse(errors)} end)
  end

  defp target_nodes(opts) do
    opts
    |> Keyword.get(:nodes, [node() | Node.list()])
    |> Enum.uniq()
  end

  defp overrides_from_module_levels(module_levels) do
    %{
      modules:
        module_levels
        |> Enum.map(fn {module, level} ->
          %{
            type: :module,
            target: module,
            target_label: Atom.to_string(module),
            level: level
          }
        end)
        |> Enum.sort_by(& &1.target_label),
      processes: []
    }
  end

  defp summarize_system_levels([]) do
    %{status: :mixed, level: nil, exceptions: []}
  end

  defp summarize_system_levels(states) do
    levels =
      states
      |> Enum.map(& &1.system_level)
      |> Enum.uniq()

    case levels do
      [level] ->
        %{status: :uniform, level: level, exceptions: []}

      _ ->
        %{
          status: :mixed,
          level: nil,
          exceptions: Enum.map(states, &%{node: &1.node, level: &1.system_level})
        }
    end
  end

  defp summarize_module_levels(states) do
    modules =
      states
      |> Enum.flat_map(fn %{module_levels: module_levels} -> Map.keys(module_levels) end)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.map(modules, fn module ->
      values =
        Enum.map(states, fn state ->
          %{node: state.node, level: Map.get(state.module_levels, module)}
        end)

      levels =
        values
        |> Enum.map(& &1.level)
        |> Enum.uniq()

      case levels do
        [level] ->
          %{
            module: module,
            module_label: Atom.to_string(module),
            status: :uniform,
            level: level,
            exceptions: []
          }

        _ ->
          %{
            module: module,
            module_label: Atom.to_string(module),
            status: :mixed,
            level: nil,
            exceptions: values
          }
      end
    end)
  end

  defp classify_result(successes, failures) do
    cond do
      successes == [] -> :failure
      failures == [] -> :success
      true -> :partial
    end
  end

  defp emit_cluster_operation(result, duration) do
    metadata = %{
      operation: result.operation,
      requested_level: result.requested_level,
      requested_module: result.requested_module && Atom.to_string(result.requested_module),
      target_node_count: length(result.target_nodes),
      success_count: length(result.successful_nodes),
      failure_count: length(result.failed_nodes),
      status: result.status
    }

    :telemetry.execute(
      [:oli, :runtime_log_overrides, :cluster_operation],
      %{duration: System.convert_time_unit(duration, :native, :millisecond)},
      metadata
    )

    log_fun =
      case result.status do
        :success -> &Logger.info/1
        :partial -> &Logger.warning/1
        :failure -> &Logger.error/1
      end

    log_fun.(
      "Cluster runtime log override operation=#{result.operation} status=#{result.status} " <>
        "target_node_count=#{metadata.target_node_count} success_count=#{metadata.success_count} " <>
        "failure_count=#{metadata.failure_count} requested_level=#{inspect(result.requested_level)} " <>
        "requested_module=#{inspect(metadata.requested_module)} failed_nodes=#{inspect(result.failed_nodes)}"
    )
  end

  defp normalize_module(module_name) when is_atom(module_name) do
    if Code.ensure_loaded?(module_name), do: {:ok, module_name}, else: {:error, :invalid_module}
  end

  defp normalize_module(module_name), do: parse_module(module_name)

  defp parse_module(module_name) when is_binary(module_name) do
    trimmed_name = String.trim(module_name)

    if trimmed_name == "" do
      {:error, :invalid_module}
    else
      normalized_name =
        case String.starts_with?(trimmed_name, "Elixir.") do
          true -> trimmed_name
          false -> "Elixir." <> trimmed_name
        end

      try do
        module = String.to_existing_atom(normalized_name)

        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error, :invalid_module}
        end
      rescue
        ArgumentError ->
          {:error, :invalid_module}
      end
    end
  end

  defp parse_module(_module_name), do: {:error, :invalid_module}

  defp validate_level(level) when is_binary(level) do
    case String.trim(level) do
      "" ->
        {:error, :invalid_level}

      trimmed_level ->
        try do
          trimmed_level
          |> String.to_existing_atom()
          |> validate_level()
        rescue
          ArgumentError -> {:error, :invalid_level}
        end
    end
  end

  defp validate_level(level) when is_atom(level) do
    case level in Logger.levels() do
      true -> {:ok, level}
      false -> {:error, :invalid_level}
    end
  end

  defp validate_level(_level), do: {:error, :invalid_level}

  defp default_system_level do
    Application.get_env(:logger, :level, Logger.level())
  end

  defp summarize_reason({:exception, exception, stacktrace}) do
    Exception.format(:error, exception, stacktrace)
  end

  defp summarize_reason(reason), do: inspect(reason)

  defp log_failed_module_override(action, module_name, level, {:error, reason}) do
    Logger.warning(
      "Runtime log override #{action} failed module=#{inspect(module_name)} level=#{inspect(level)} reason=#{inspect(reason)} node=#{node()}"
    )
  end
end
