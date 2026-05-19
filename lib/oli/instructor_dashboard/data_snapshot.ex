defmodule Oli.InstructorDashboard.DataSnapshot do
  @moduledoc """
  Instructor dashboard snapshot orchestration facade.

  This module consumes cache/runtime interfaces and exposes deterministic
  snapshot + projection bundles for dashboard consumers.
  """

  require Logger

  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.InstructorDashboard.OracleRegistry

  @type scope_request :: map() | keyword()
  @type dependency_profile :: %{required: [atom() | String.t()], optional: [atom() | String.t()]}

  @type snapshot_bundle :: %{
          required(:snapshot) => Contract.t(),
          required(:projections) => map(),
          required(:projection_statuses) => map(),
          required(:context) => OracleContext.t(),
          required(:scope) => Scope.t(),
          required(:request_token) => String.t(),
          required(:dependency_profile) => dependency_profile()
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
           orchestrate_oracle_results(context, scope, dependency_profile, scope_request, opts),
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

      maybe_store_memoized_bundle(memo_key, base_snapshot_bundle, opts)
      {:ok, base_snapshot_bundle}
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

  defp orchestrate_oracle_results(context, scope, dependency_profile, scope_request, opts) do
    request_token = resolve_request_token(scope_request, opts)

    with {:ok, cached_oracle_results, misses} <-
           required_results_from_cache(context, scope, dependency_profile.required, opts),
         runtime_oracle_results <-
           runtime_results_for(
             request_token,
             misses,
             dependency_profile,
             context,
             scope,
             opts
           ),
         :ok <- write_runtime_results_to_cache(context, scope, runtime_oracle_results, opts),
         {:ok, merged_results} <-
           Assembler.merge_oracle_results(cached_oracle_results, runtime_oracle_results) do
      {:ok, request_token, merged_results}
    else
      {:error, reason} -> {:error, {:orchestration_failed, reason}}
    end
  end

  defp required_results_from_cache(_context, _scope, [], _opts), do: {:ok, %{}, []}

  defp required_results_from_cache(context, scope, required_oracles, opts) do
    required_oracles = dedupe_ordered(required_oracles)

    case lookup_required_from_cache(context, scope, required_oracles, opts) do
      {:ok, lookup_result} ->
        {:ok, hits} = normalize_cache_hits(required_oracles, Map.get(lookup_result, :hits, %{}))
        cache_source = Map.get(lookup_result, :source, :none)
        misses = Enum.reject(required_oracles, &Map.has_key?(hits, &1))

        {:ok, cached_results_from_hits(hits, cache_source), misses}

      {:error, _reason} ->
        {:ok, %{}, required_oracles}
    end
  end

  defp lookup_required_from_cache(_context, _scope, required_oracles, opts)
       when not is_list(opts) do
    {:ok, %{hits: %{}, misses: required_oracles, source: :none}}
  end

  defp lookup_required_from_cache(context, scope, required_oracles, opts) do
    cache_module = Keyword.get(opts, :cache_module)

    cond do
      is_nil(cache_module) ->
        {:ok, %{hits: %{}, misses: required_oracles, source: :none}}

      not function_exported?(cache_module, :lookup_required, 4) ->
        {:ok, %{hits: %{}, misses: required_oracles, source: :none}}

      true ->
        case cache_module.lookup_required(context, scope, required_oracles, cache_opts(opts)) do
          {:ok, %{} = lookup_result} -> {:ok, lookup_result}
          {:error, reason} -> {:error, reason}
          other -> {:error, {:invalid_cache_lookup_result, other}}
        end
    end
  end

  defp normalize_cache_hits(required_oracles, hits) when is_map(hits) do
    required_set = MapSet.new(required_oracles)

    {:ok,
     Enum.reduce(hits, %{}, fn {oracle_key, payload}, acc ->
       if MapSet.member?(required_set, oracle_key) do
         Map.put(acc, oracle_key, payload)
       else
         acc
       end
     end)}
  end

  defp normalize_cache_hits(_required_oracles, _hits), do: {:ok, %{}}

  defp cached_results_from_hits(hits, cache_source) do
    Enum.reduce(hits, %{}, fn {oracle_key, payload}, acc ->
      Map.put(
        acc,
        oracle_key,
        Result.ok(oracle_key, payload,
          metadata: %{
            source: :cache,
            cache_source: normalize_cache_source(cache_source)
          }
        )
      )
    end)
  end

  defp normalize_cache_source(value) when value in [:inprocess, :revisit, :mixed, :none],
    do: value

  defp normalize_cache_source(_), do: :unknown

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

  defp write_runtime_results_to_cache(_context, _scope, runtime_results, _opts)
       when map_size(runtime_results) == 0 do
    :ok
  end

  defp write_runtime_results_to_cache(context, scope, runtime_results, opts) do
    cache_module = Keyword.get(opts, :cache_module)

    if is_nil(cache_module) or not function_exported?(cache_module, :write_oracle, 6) do
      :ok
    else
      cache_opts = cache_opts(opts)

      Enum.each(runtime_results, fn {oracle_key, oracle_result} ->
        write_runtime_result_to_cache(
          cache_module,
          context,
          scope,
          oracle_key,
          oracle_result,
          cache_opts,
          opts
        )
      end)

      :ok
    end
  end

  defp write_runtime_result_to_cache(
         cache_module,
         context,
         scope,
         oracle_key,
         oracle_result,
         cache_opts,
         opts
       ) do
    case cache_payload(oracle_result) do
      {:ok, payload} ->
        key_meta = build_cache_key_meta(context, scope, oracle_key, oracle_result, opts)

        try do
          case cache_module.write_oracle(
                 context,
                 scope,
                 oracle_key,
                 payload,
                 key_meta,
                 cache_opts
               ) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.debug(
                "data snapshot cache write rejected oracle_key=#{inspect(oracle_key)} reason=#{inspect(reason)}"
              )
          end
        catch
          :exit, reason ->
            Logger.debug(
              "data snapshot cache write exited oracle_key=#{inspect(oracle_key)} reason=#{inspect(reason)}"
            )
        end

      {:skip, _reason} ->
        :ok
    end
  end

  defp cache_payload(oracle_result) do
    status = runtime_result_field(oracle_result, :status)
    payload = runtime_result_field(oracle_result, :payload)

    cond do
      status in [:error, "error"] ->
        {:skip, :oracle_error}

      status in [:ok, "ok"] ->
        {:ok, payload}

      is_map(oracle_result) ->
        {:ok, oracle_result}

      true ->
        {:skip, :invalid_oracle_result}
    end
  end

  defp build_cache_key_meta(context, scope, oracle_key, oracle_result, opts) do
    default_meta =
      case Keyword.get(opts, :key_meta, %{oracle_version: 1, data_version: 1}) do
        %{} = map -> map
        keyword when is_list(keyword) -> Map.new(keyword)
        _ -> %{oracle_version: 1, data_version: 1}
      end

    key_meta_by_oracle =
      opts
      |> Keyword.get(:key_meta_by_oracle, %{})
      |> normalize_meta_map()

    per_oracle_meta =
      Map.get(key_meta_by_oracle, oracle_key) ||
        Map.get(key_meta_by_oracle, to_string(oracle_key))

    base_meta =
      case per_oracle_meta do
        nil -> default_meta
        %{} = map -> map
        keyword when is_list(keyword) -> Map.new(keyword)
        _ -> default_meta
      end

    base_meta
    |> Map.put(:oracle_version, runtime_oracle_version(oracle_result, base_meta))
    |> Map.put(:data_version, runtime_data_version(oracle_result, base_meta))
    |> Map.put(:dashboard_context_id, context.dashboard_context_id)
    |> Map.put(:container_type, scope.container_type)
    |> Map.put(:container_id, scope.container_id)
  end

  defp runtime_oracle_version(oracle_result, base_meta) do
    case runtime_result_field(oracle_result, :oracle_version) do
      value when is_integer(value) and value >= 0 ->
        value

      _ ->
        Map.get(base_meta, :oracle_version, 1)
    end
  end

  defp runtime_data_version(oracle_result, base_meta) do
    metadata = runtime_result_field(oracle_result, :metadata)

    case runtime_result_field(oracle_result, :data_version) ||
           (is_map(metadata) &&
              (Map.get(metadata, :data_version) || Map.get(metadata, "data_version"))) do
      value when is_integer(value) and value >= 0 ->
        value

      _ ->
        Map.get(base_meta, :data_version, 1)
    end
  end

  defp runtime_result_field(%{} = result, field) do
    Map.get(result, field) || Map.get(result, Atom.to_string(field))
  end

  defp runtime_result_field(_, _field), do: nil

  defp normalize_meta_map(meta_map) when is_map(meta_map), do: meta_map
  defp normalize_meta_map(meta_map) when is_list(meta_map), do: Map.new(meta_map)
  defp normalize_meta_map(_), do: %{}

  defp cache_opts(opts) do
    case Keyword.get(opts, :cache_opts, []) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp resolve_request_token(scope_request, opts) do
    scope_request
    |> Map.get(
      :request_token,
      Map.get(scope_request, :request_id, Keyword.get(opts, :request_token, 1))
    )
    |> normalize_request_token()
  end

  defp normalize_request_token(value) when is_integer(value) and value > 0 do
    Integer.to_string(value)
  end

  defp normalize_request_token(value) when is_binary(value) and byte_size(value) > 0 do
    value
  end

  defp normalize_request_token(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_request_token(_value), do: "1"

  defp projection_opts(opts) do
    projection_modules = Keyword.get(opts, :projection_modules)
    projection_opts = Keyword.get(opts, :projection_opts, [])

    []
    |> maybe_put_opt(:projection_modules, projection_modules)
    |> Keyword.merge(projection_opts)
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
end
