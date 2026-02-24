defmodule Oli.InstructorDashboard.DataSnapshot do
  @moduledoc """
  Instructor dashboard snapshot orchestration facade.

  This module consumes coordinator/cache interfaces and exposes deterministic
  snapshot + projection bundles for dashboard consumers.
  """

  require Logger

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Parity
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.InstructorDashboard.OracleRegistry

  @type scope_request :: map() | keyword()
  @type dependency_profile :: %{required: [atom() | String.t()], optional: [atom() | String.t()]}
  @type parity_metadata :: %{
          required(:fingerprint) => String.t(),
          required(:projection_keys) => [String.t()]
        }

  @type snapshot_bundle :: %{
          required(:snapshot) => Contract.t(),
          required(:projections) => map(),
          required(:projection_statuses) => map(),
          required(:context) => OracleContext.t(),
          required(:scope) => Scope.t(),
          required(:request_token) => String.t(),
          required(:dependency_profile) => dependency_profile(),
          required(:parity) => parity_metadata()
        }

  @type error ::
          {:invalid_scope_request, term()}
          | {:unauthorized_scope, term()}
          | {:orchestration_failed, term()}
          | {:snapshot_assembly_failed, term()}
          | {:projection_failed, term()}
          | {:projection_unavailable, atom() | String.t(), atom(), atom() | nil}

  @boundary_non_goals [
    :queue_token_orchestration,
    :cache_policy,
    :direct_oracle_queries,
    :direct_analytics_queries
  ]

  @doc """
  Builds or retrieves a canonical snapshot bundle for a normalized scope request.
  """
  @spec get_or_build(scope_request(), keyword()) :: {:ok, snapshot_bundle()} | {:error, error()}
  def get_or_build(scope_request, opts \\ [])

  def get_or_build(scope_request, opts) when is_list(scope_request),
    do: get_or_build(Map.new(scope_request), opts)

  def get_or_build(%{} = scope_request, opts) do
    with {:ok, context, scope} <- normalize_scope_request(scope_request),
         :ok <- authorize_scope(context, scope, opts),
         {:ok, dependency_profile} <- resolve_dependency_profile(scope_request, opts),
         {:ok, memo_key} <- memo_key(context, scope, dependency_profile, scope_request),
         {:miss, nil} <- maybe_fetch_memoized_bundle(memo_key, opts),
         {:ok, request_token, oracle_results} <-
           orchestrate_oracle_results(context, scope, dependency_profile, opts),
         {:ok, snapshot} <-
           Assembler.assemble(context, request_token, oracle_results,
             scope: scope,
             expected_oracles: dependency_profile.required ++ dependency_profile.optional,
             metadata: metadata_from_scope_request(scope_request)
           ),
         {:ok, %{projections: projection_map, statuses: projection_statuses}} <-
           Projections.derive_all(snapshot, projection_opts(opts)) do
      base_snapshot_bundle = %{
        snapshot: %{
          snapshot
          | projections: projection_map,
            projection_statuses: projection_statuses
        },
        projections: projection_map,
        projection_statuses: projection_statuses,
        context: context,
        scope: scope,
        request_token: request_token,
        dependency_profile: dependency_profile
      }

      snapshot_bundle =
        Map.put(base_snapshot_bundle, :parity, build_parity_metadata(base_snapshot_bundle))

      maybe_store_memoized_bundle(memo_key, snapshot_bundle, opts)
      {:ok, snapshot_bundle}
    else
      {:hit, bundle} ->
        {:ok, bundle}

      {:error, reason} ->
        Logger.error("data snapshot orchestration failed reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_or_build(other, _opts), do: {:error, {:invalid_scope_request, other}}

  @doc """
  Gets a projection from a prebuilt snapshot bundle with deterministic errors.
  """
  @spec get_projection(snapshot_bundle(), atom() | String.t(), keyword()) ::
          {:ok, map()} | {:error, error()}
  def get_projection(snapshot_bundle, capability_key, opts \\ [])

  def get_projection(
        %{projections: projections, projection_statuses: statuses},
        capability_key,
        opts
      )
      when is_map(projections) and is_map(statuses) do
    allow_partial = Keyword.get(opts, :allow_partial, true)

    case {Map.get(projections, capability_key), Map.get(statuses, capability_key)} do
      {projection, %{status: :ready}} when is_map(projection) ->
        {:ok, projection}

      {projection, %{status: :partial}} when is_map(projection) and allow_partial ->
        {:ok, projection}

      {_projection, %{status: :partial, reason_code: reason_code}} ->
        {:error, {:projection_unavailable, capability_key, :partial, reason_code}}

      {_projection, %{status: :failed, reason_code: reason_code}} ->
        {:error, {:projection_unavailable, capability_key, :failed, reason_code}}

      {_projection, %{status: :unavailable, reason_code: reason_code}} ->
        {:error, {:projection_unavailable, capability_key, :unavailable, reason_code}}

      _ ->
        {:error, {:projection_unavailable, capability_key, :unavailable, nil}}
    end
  end

  def get_projection(_snapshot_bundle, capability_key, _opts) do
    {:error, {:projection_unavailable, capability_key, :unavailable, nil}}
  end

  @doc """
  Explicit boundary declarations used by orchestration boundary tests.
  """
  @spec boundary_non_goals() :: [atom()]
  def boundary_non_goals, do: @boundary_non_goals

  defp normalize_scope_request(%{} = scope_request) do
    context_input = Map.get(scope_request, :context, scope_request)
    explicit_scope = Map.get(scope_request, :scope)

    with {:ok, context} <- OracleContext.new(context_input),
         {:ok, scope} <- normalize_scope(explicit_scope, context),
         :ok <- ensure_scope_matches_context(scope, context) do
      {:ok, OracleContext.with_scope(context, scope), scope}
    else
      {:error, reason} -> {:error, {:invalid_scope_request, reason}}
    end
  end

  defp normalize_scope(nil, %OracleContext{scope: scope}), do: {:ok, scope}

  defp normalize_scope(scope_input, _context) do
    Scope.new(scope_input)
  end

  defp ensure_scope_matches_context(scope, context) do
    if Scope.container_key(scope) == Scope.container_key(context.scope) do
      :ok
    else
      {:error,
       {:scope_context_mismatch,
        %{scope: Scope.container_key(scope), context_scope: Scope.container_key(context.scope)}}}
    end
  end

  defp authorize_scope(context, scope, opts) do
    authorize_fun = Keyword.get(opts, :authorize_fun, fn _context, _scope -> :ok end)

    case authorize_fun.(context, scope) do
      :ok -> :ok
      true -> :ok
      {:ok, _} -> :ok
      false -> {:error, {:unauthorized_scope, :forbidden}}
      {:error, reason} -> {:error, {:unauthorized_scope, reason}}
      other -> {:error, {:unauthorized_scope, other}}
    end
  end

  defp resolve_dependency_profile(scope_request, opts) do
    dependency_profile =
      Keyword.get(opts, :dependency_profile) ||
        Map.get(scope_request, :dependency_profile)

    case dependency_profile do
      nil ->
        resolve_dependency_profile_from_consumers(scope_request, opts)

      profile ->
        normalize_dependency_profile(profile)
    end
  end

  defp resolve_dependency_profile_from_consumers(scope_request, opts) do
    consumer_keys =
      Keyword.get(opts, :consumer_keys) ||
        Map.get(scope_request, :consumer_keys) ||
        []

    consumer_keys =
      consumer_keys
      |> List.wrap()
      |> Enum.reject(&is_nil/1)

    if consumer_keys == [] do
      {:ok, %{required: [], optional: []}}
    else
      Enum.reduce_while(consumer_keys, {:ok, %{required: [], optional: []}}, fn consumer_key,
                                                                                {:ok, acc} ->
        case OracleRegistry.dependencies_for(consumer_key) do
          {:ok, %{required: required, optional: optional}} ->
            {:cont,
             {:ok,
              %{
                required: dedupe_ordered(acc.required ++ required),
                optional: dedupe_ordered(acc.optional ++ optional)
              }}}

          {:error, reason} ->
            {:halt, {:error, {:orchestration_failed, {:dependency_resolution_failed, reason}}}}
        end
      end)
    end
  end

  defp normalize_dependency_profile(%{} = profile) do
    required = normalize_oracle_keys(Map.get(profile, :required, []))
    optional = normalize_oracle_keys(Map.get(profile, :optional, []))
    {:ok, %{required: required, optional: optional}}
  end

  defp normalize_dependency_profile(other),
    do: {:error, {:orchestration_failed, {:invalid_dependency_profile, other}}}

  defp normalize_oracle_keys(keys) do
    keys
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
    |> dedupe_ordered()
  end

  defp dedupe_ordered(list) do
    Enum.reduce(list, [], fn item, acc ->
      if item in acc do
        acc
      else
        acc ++ [item]
      end
    end)
  end

  defp orchestrate_oracle_results(context, scope, dependency_profile, opts) do
    coordinator_module = Keyword.get(opts, :coordinator_module, LiveDataCoordinator)
    coordinator_state = Keyword.get(opts, :coordinator_state, coordinator_module.new_session())
    coordinator_opts = coordinator_opts(context, opts)

    with {:ok, state_after_request, request_actions} <-
           request_scope_change(
             coordinator_module,
             coordinator_state,
             scope,
             dependency_profile,
             coordinator_opts
           ),
         {:ok, request_token} <- request_token_from_actions(request_actions),
         cached_oracle_results <- cached_results_from_actions(request_actions),
         misses <- misses_from_actions(request_actions),
         runtime_oracle_results <-
           runtime_results_for(
             request_token,
             misses,
             dependency_profile,
             context,
             scope,
             opts
           ),
         {:ok, _state_after_runtime} <-
           apply_runtime_results(
             state_after_request,
             request_token,
             runtime_oracle_results,
             coordinator_module,
             coordinator_opts
           ),
         {:ok, merged_results} <-
           Assembler.merge_oracle_results(cached_oracle_results, runtime_oracle_results) do
      {:ok, Integer.to_string(request_token), merged_results}
    else
      {:error, reason} -> {:error, {:orchestration_failed, reason}}
    end
  end

  defp coordinator_opts(context, opts) do
    cache_module = Keyword.get(opts, :cache_module)
    cache_opts = Keyword.get(opts, :cache_opts, [])
    timeout_ms = Keyword.get(opts, :timeout_ms)

    [context: context]
    |> maybe_put_opt(:cache_module, cache_module)
    |> maybe_put_opt(:cache_opts, cache_opts)
    |> maybe_put_opt(:timeout_ms, timeout_ms)
  end

  defp request_scope_change(
         coordinator_module,
         coordinator_state,
         scope,
         dependency_profile,
         coordinator_opts
       ) do
    case coordinator_module.request_scope_change(
           coordinator_state,
           scope,
           dependency_profile,
           coordinator_opts
         ) do
      {:ok, next_state, actions} ->
        {:ok, next_state, actions}

      {:error, reason, _next_state, _actions} ->
        {:error, {:request_scope_change_failed, reason}}

      other ->
        {:error, {:request_scope_change_failed, other}}
    end
  end

  defp request_token_from_actions(actions) do
    case Enum.find(actions, &(&1.type in [:request_started, :request_promoted])) do
      %{request_token: request_token} -> {:ok, request_token}
      _ -> {:error, :missing_request_token}
    end
  end

  defp cached_results_from_actions(actions) do
    actions
    |> Enum.filter(&(&1.type == :emit_required_ready))
    |> Enum.reduce(%{}, fn %{hits: hits}, acc ->
      Enum.reduce(hits, acc, fn {oracle_key, payload}, results_acc ->
        Map.put(
          results_acc,
          oracle_key,
          Result.ok(oracle_key, payload, metadata: %{source: :cache})
        )
      end)
    end)
  end

  defp misses_from_actions(actions) do
    actions
    |> Enum.filter(&(&1.type == :runtime_start))
    |> Enum.flat_map(&Map.get(&1, :misses, []))
    |> dedupe_ordered()
  end

  defp runtime_results_for(request_token, misses, dependency_profile, context, scope, opts) do
    provider = Keyword.get(opts, :runtime_results_provider)
    provided_results = Keyword.get(opts, :runtime_results, %{})

    raw_results =
      cond do
        is_function(provider, 4) -> provider.(request_token, misses, context, scope)
        is_map(provided_results) -> provided_results
        is_list(provided_results) -> Map.new(provided_results)
        true -> %{}
      end
      |> normalize_runtime_result_container()

    requested_oracle_keys = dedupe_ordered(misses ++ dependency_profile.optional)

    Enum.reduce(requested_oracle_keys, %{}, fn oracle_key, acc ->
      case Map.fetch(raw_results, oracle_key) do
        {:ok, result} -> Map.put(acc, oracle_key, normalize_runtime_result(oracle_key, result))
        :error -> acc
      end
    end)
  end

  defp normalize_runtime_result(_oracle_key, %{status: _} = result), do: result
  defp normalize_runtime_result(_oracle_key, %{"status" => _} = result), do: result

  defp normalize_runtime_result(oracle_key, {:error, reason}),
    do: Result.error(oracle_key, reason)

  defp normalize_runtime_result(oracle_key, payload), do: Result.ok(oracle_key, payload)

  defp normalize_runtime_result_container(results) when is_map(results), do: results
  defp normalize_runtime_result_container(results) when is_list(results), do: Map.new(results)
  defp normalize_runtime_result_container(_), do: %{}

  defp apply_runtime_results(state, _request_token, runtime_results, _coordinator_module, _opts)
       when map_size(runtime_results) == 0 do
    {:ok, state}
  end

  defp apply_runtime_results(
         state,
         request_token,
         runtime_results,
         coordinator_module,
         coordinator_opts
       ) do
    runtime_results
    |> Enum.sort_by(fn {oracle_key, _oracle_result} -> to_string(oracle_key) end)
    |> Enum.reduce_while({:ok, state}, fn {oracle_key, oracle_result}, {:ok, acc_state} ->
      case coordinator_module.handle_oracle_result(
             acc_state,
             request_token,
             oracle_key,
             oracle_result,
             coordinator_opts
           ) do
        {:ok, next_state, _actions} -> {:cont, {:ok, next_state}}
        {:error, reason, _failed_state, _actions} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp projection_opts(opts) do
    projection_modules = Keyword.get(opts, :projection_modules)

    []
    |> maybe_put_opt(:projection_modules, projection_modules)
  end

  defp metadata_from_scope_request(scope_request) do
    metadata = Map.get(scope_request, :metadata, %{})

    metadata
    |> case do
      map when is_map(map) -> map
      keyword when is_list(keyword) -> Map.new(keyword)
      _ -> %{}
    end
    |> Map.put_new(:dashboard_product, :instructor_dashboard)
  end

  defp memo_key(context, scope, dependency_profile, scope_request) do
    {:ok,
     {context.dashboard_context_type, context.dashboard_context_id, Scope.container_key(scope),
      dependency_profile, Map.get(scope_request, :request_id)}}
  end

  defp maybe_fetch_memoized_bundle(memo_key, opts) do
    if Keyword.get(opts, :memoize, false) do
      case Process.get({__MODULE__, memo_key}) do
        nil -> {:miss, nil}
        bundle -> {:hit, bundle}
      end
    else
      {:miss, nil}
    end
  end

  defp maybe_store_memoized_bundle(memo_key, bundle, opts) do
    if Keyword.get(opts, :memoize, false) do
      Process.put({__MODULE__, memo_key}, bundle)
    end

    :ok
  end

  defp maybe_put_opt(list, _key, nil), do: list
  defp maybe_put_opt(list, _key, []), do: list
  defp maybe_put_opt(list, key, value), do: Keyword.put(list, key, value)

  defp build_parity_metadata(snapshot_bundle) do
    projection_specs =
      snapshot_bundle
      |> Map.get(:projections, %{})
      |> Map.keys()
      |> Enum.sort_by(&to_string/1)
      |> Enum.map(&%{dataset_id: &1})

    %{
      fingerprint: Parity.fingerprint(snapshot_bundle, projection_specs),
      projection_keys: Enum.map(projection_specs, &(&1.dataset_id |> to_string()))
    }
  end
end
