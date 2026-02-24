defmodule Oli.Dashboard.LiveDataCoordinator do
  @moduledoc """
  Session-scoped request orchestration facade for the dashboard runtime.

  This module intentionally owns queue/token orchestration contracts and must not
  implement cache policy internals such as key construction, TTL freshness,
  container LRU, revisit retention, or miss coalescing algorithms.
  """

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.LiveDataCoordinator.Actions
  alias Oli.Dashboard.LiveDataCoordinator.State
  alias Oli.Dashboard.LiveDataCoordinator.Telemetry
  alias Oli.Dashboard.Scope

  @typedoc "Coordinator state."
  @type state :: State.t()

  @typedoc "Coordinator transition result."
  @type transition_result :: State.transition_result()

  @typedoc "Coordinator action envelope."
  @type action :: Actions.t()

  @typedoc "Coordinator request token."
  @type request_token :: State.request_token()

  @typedoc "Coordinator dependency profile input."
  @type dependency_profile_input :: State.dependency_profile_input()

  @typedoc "Coordinator error."
  @type error :: State.transition_error()

  @typedoc "Request-scope change options."
  @type request_opts :: keyword()

  @doc """
  Creates a new coordinator session state.
  """
  @spec new_session(keyword()) :: state()
  def new_session(opts \\ []) do
    State.new(opts)
  end

  @doc """
  Handles a scope-change request and emits deterministic transition actions.
  """
  @spec request_scope_change(state(), Scope.input(), dependency_profile_input(), request_opts()) ::
          transition_result()
  def request_scope_change(state, scope, dependency_profile \\ %{}, opts \\ [])

  def request_scope_change(state, scope_input, dependency_profile, opts) do
    with {:ok, scope} <- Scope.new(scope_input),
         {:ok, context} <- context_for_lookup(opts, scope),
         {:ok, next_state, transition_actions} <-
           State.request_scope_change(state, scope, dependency_profile, context) do
      {final_state, final_actions} =
        process_activation_actions(next_state, transition_actions, opts)

      emit_telemetry(final_actions, opts)
      {:ok, final_state, final_actions}
    else
      {:error, reason, next_state, actions} ->
        {:error, reason, next_state, actions}

      {:error, reason} ->
        normalized_reason = normalize_request_error(reason)
        {:error, normalized_reason, state, [Actions.invalid_transition(normalized_reason)]}
    end
  end

  @doc """
  Handles an oracle completion envelope for a given request token.
  """
  @spec handle_oracle_result(state(), request_token(), State.oracle_key(), map(), request_opts()) ::
          transition_result()
  def handle_oracle_result(state, request_token, oracle_key, oracle_result, opts \\ []) do
    with {:ok, next_state, transition_actions} <-
           State.handle_oracle_result(state, request_token, oracle_key, oracle_result) do
      actions_with_cache_write =
        transition_actions ++
          maybe_cache_write_action(
            next_state,
            request_token,
            oracle_key,
            oracle_result,
            transition_actions,
            opts
          )

      {final_state, final_actions} =
        process_activation_actions(next_state, actions_with_cache_write, opts)

      emit_telemetry(final_actions, opts)
      {:ok, final_state, final_actions}
    else
      {:error, reason, next_state, actions} ->
        {:error, reason, next_state, actions}
    end
  end

  @doc """
  Handles request timeout callbacks for the active token.
  """
  @spec handle_request_timeout(state(), request_token(), request_opts()) :: transition_result()
  def handle_request_timeout(state, request_token, opts \\ []) do
    with {:ok, next_state, transition_actions} <- State.handle_timeout(state, request_token) do
      {final_state, final_actions} =
        process_activation_actions(next_state, transition_actions, opts)

      emit_telemetry(final_actions, opts)
      {:ok, final_state, final_actions}
    else
      {:error, reason, next_state, actions} ->
        {:error, reason, next_state, actions}
    end
  end

  @doc """
  Alias for `handle_request_timeout/2` to preserve concise timeout-hook naming.
  """
  @spec handle_timeout(state(), request_token(), request_opts()) :: transition_result()
  def handle_timeout(state, request_token, opts \\ []) do
    handle_request_timeout(state, request_token, opts)
  end

  @doc """
  Explicit boundary declarations used by coordinator boundary tests.
  """
  @spec boundary_non_goals() :: [atom()]
  def boundary_non_goals do
    [:cache_keying, :ttl_policy, :lru_eviction, :revisit_retention, :miss_coalescing]
  end

  defp process_activation_actions(state, transition_actions, opts) do
    do_process_activation_actions(state, transition_actions, transition_actions, opts)
  end

  defp do_process_activation_actions(state, actions_acc, [], _opts), do: {state, actions_acc}

  defp do_process_activation_actions(state, actions_acc, [action | rest], opts) do
    case activation_request(action) do
      {:ok, request_token, context, scope, dependency_profile} ->
        required_oracles = Map.get(dependency_profile, :required, [])

        {lookup_actions, misses} =
          consult_cache_for_required(request_token, context, scope, required_oracles, opts)

        {state_after_register, register_actions} =
          register_required_misses(state, request_token, misses)

        new_actions = lookup_actions ++ register_actions

        do_process_activation_actions(
          state_after_register,
          actions_acc ++ new_actions,
          rest ++ new_actions,
          opts
        )

      :ignore ->
        do_process_activation_actions(state, actions_acc, rest, opts)
    end
  end

  defp consult_cache_for_required(request_token, context, scope, required_oracles, opts) do
    cache_module = Keyword.get(opts, :cache_module, Cache)
    cache_opts = Keyword.get(opts, :cache_opts, [])

    case cache_module.lookup_required(context, scope, required_oracles, cache_opts) do
      {:ok, lookup_result} ->
        cache_actions_from_lookup(request_token, context, scope, required_oracles, lookup_result)

      {:error, _reason} ->
        fallback_cache_actions(request_token, context, scope, required_oracles)
    end
  end

  defp cache_actions_from_lookup(request_token, context, scope, required_oracles, lookup_result) do
    hits = normalize_hits(required_oracles, Map.get(lookup_result, :hits))
    misses = normalize_misses(required_oracles, hits)
    cache_source = normalize_cache_source(Map.get(lookup_result, :source))
    cache_outcome = derive_cache_outcome(hits, misses)

    base_actions = [
      Actions.cache_consulted(request_token, cache_outcome, hits, misses, cache_source)
      |> annotate_context(context, scope)
    ]

    base_actions =
      if map_size(hits) > 0 do
        base_actions ++ [Actions.emit_required_ready(request_token, hits, cache_source)]
      else
        base_actions
      end

    actions =
      if misses == [] do
        base_actions
      else
        base_actions ++
          [
            Actions.emit_loading(request_token, misses),
            Actions.runtime_start(request_token, misses)
          ]
      end

    {actions, misses}
  end

  defp fallback_cache_actions(request_token, context, scope, required_oracles) do
    {[
       Actions.cache_consulted(request_token, :error, %{}, required_oracles, :unknown)
       |> annotate_context(context, scope),
       Actions.emit_loading(request_token, required_oracles),
       Actions.runtime_start(request_token, required_oracles)
     ], required_oracles}
  end

  defp normalize_hits(required_oracles, hits) when is_map(hits) do
    required_set = MapSet.new(required_oracles)

    Enum.reduce(hits, %{}, fn {oracle_key, payload}, acc ->
      if MapSet.member?(required_set, oracle_key) do
        Map.put(acc, oracle_key, payload)
      else
        acc
      end
    end)
  end

  defp normalize_hits(_required_oracles, _hits), do: %{}

  defp normalize_misses(required_oracles, hits) do
    Enum.reject(required_oracles, &Map.has_key?(hits, &1))
  end

  defp derive_cache_outcome(hits, []), do: if(map_size(hits) > 0, do: :full_hit, else: :miss)

  defp derive_cache_outcome(hits, _misses),
    do: if(map_size(hits) > 0, do: :partial_hit, else: :miss)

  defp normalize_cache_source(:inprocess), do: :inprocess
  defp normalize_cache_source(:revisit), do: :revisit
  defp normalize_cache_source(:mixed), do: :mixed
  defp normalize_cache_source(:none), do: :none
  defp normalize_cache_source(_), do: :unknown

  defp activation_request(%{
         type: type,
         request_token: request_token,
         context: context,
         scope: scope,
         dependency_profile: dependency_profile
       })
       when type in [:request_started, :request_promoted] do
    {:ok, request_token, context, scope, dependency_profile}
  end

  defp activation_request(_action), do: :ignore

  defp register_required_misses(state, request_token, misses) do
    case State.register_required_misses(state, request_token, misses) do
      {:ok, next_state, actions} -> {next_state, actions}
      {:error, _reason, next_state, actions} -> {next_state, actions}
    end
  end

  defp maybe_cache_write_action(
         state,
         request_token,
         oracle_key,
         oracle_result,
         transition_actions,
         opts
       ) do
    case oracle_result_token_state(transition_actions) do
      token_state when token_state in [:active, :stale] ->
        cache_write_action(
          state,
          request_token,
          token_state,
          oracle_key,
          oracle_result,
          opts
        )

      _ ->
        []
    end
  end

  defp cache_write_action(state, request_token, token_state, oracle_key, oracle_result, opts) do
    with {:ok, _resolved_state, request} <- State.request_for_token(state, request_token),
         {:ok, payload} <- cache_payload(oracle_result) do
      cache_module = Keyword.get(opts, :cache_module, Cache)
      active_scope = active_scope_for_write(state)
      write_mode = derive_write_mode(request.scope, active_scope)
      cache_opts = Keyword.get(opts, :cache_opts, [])
      key_meta = write_key_meta(request, oracle_result, opts)
      write_opts = cache_opts ++ [active_scope: active_scope]

      write_action =
        case maybe_write_to_cache(
               cache_module,
               request.context,
               request.scope,
               oracle_key,
               payload,
               key_meta,
               write_opts
             ) do
          :ok ->
            Actions.cache_write(request_token, token_state, oracle_key, write_mode, :accepted)

          {:error, {:identity_guard_rejected, _} = reason} ->
            Actions.cache_write(
              request_token,
              token_state,
              oracle_key,
              write_mode,
              :rejected,
              reason
            )

          {:error, reason} ->
            Actions.cache_write(
              request_token,
              token_state,
              oracle_key,
              write_mode,
              :error,
              reason
            )
        end

      [write_action]
    else
      {:skip, reason} ->
        write_mode =
          case State.request_for_token(state, request_token) do
            {:ok, _resolved_state, request} ->
              derive_write_mode(request.scope, active_scope_for_write(state))

            _ ->
              :active
          end

        [
          Actions.cache_write(
            request_token,
            token_state,
            oracle_key,
            write_mode,
            :skipped,
            reason
          )
        ]

      {:error, reason} ->
        [Actions.cache_write(request_token, token_state, oracle_key, :active, :skipped, reason)]
    end
  end

  defp maybe_write_to_cache(
         cache_module,
         context,
         scope,
         oracle_key,
         payload,
         key_meta,
         write_opts
       ) do
    if function_exported?(cache_module, :write_oracle, 6) do
      cache_module.write_oracle(context, scope, oracle_key, payload, key_meta, write_opts)
    else
      {:error, :cache_write_unavailable}
    end
  end

  defp oracle_result_token_state(actions) do
    Enum.find_value(actions, fn
      %{type: :oracle_result_received, token_state: token_state} -> token_state
      _ -> nil
    end)
  end

  defp cache_payload(%{status: :error}), do: {:skip, :oracle_error}
  defp cache_payload(%{status: :ok, payload: payload}) when is_map(payload), do: {:ok, payload}
  defp cache_payload(%{status: :ok, payload: payload}), do: {:skip, {:invalid_payload, payload}}

  defp cache_payload(%{} = oracle_result) do
    case Map.fetch(oracle_result, :payload) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      {:ok, payload} -> {:skip, {:invalid_payload, payload}}
      :error -> {:ok, oracle_result}
    end
  end

  defp write_key_meta(request, oracle_result, opts) do
    default_meta =
      Keyword.get(opts, :key_meta, %{
        oracle_version: 1,
        data_version: 1
      })

    base_meta =
      case default_meta do
        %{} = map -> map
        keyword when is_list(keyword) -> Map.new(keyword)
        _ -> %{oracle_version: 1, data_version: 1}
      end

    base_meta
    |> Map.put(
      :oracle_version,
      Map.get(oracle_result, :oracle_version, Map.get(base_meta, :oracle_version, 1))
    )
    |> Map.put(
      :data_version,
      Map.get(oracle_result, :data_version, Map.get(base_meta, :data_version, 1))
    )
    |> Map.put(:dashboard_context_id, request.context.dashboard_context_id)
    |> Map.put(:container_type, request.scope.container_type)
    |> Map.put(:container_id, request.scope.container_id)
  end

  defp active_scope_for_write(state) do
    case state do
      %State{active_request: %{scope: scope}} -> scope
      _ -> nil
    end
  end

  defp derive_write_mode(_request_scope, nil), do: :active

  defp derive_write_mode(request_scope, active_scope) do
    if request_scope.container_type == active_scope.container_type and
         request_scope.container_id == active_scope.container_id do
      :active
    else
      :late
    end
  end

  defp context_for_lookup(opts, scope) do
    with {:ok, context_input} <- fetch_context_input(opts),
         {:ok, context} <- OracleContext.new(context_input) do
      {:ok, OracleContext.with_scope(context, scope)}
    end
  end

  defp fetch_context_input(opts) do
    case Keyword.fetch(opts, :context) do
      {:ok, context_input} -> {:ok, context_input}
      :error -> {:error, :missing_context}
    end
  end

  defp normalize_request_error({:invalid_scope, _reason} = reason), do: reason

  defp normalize_request_error({:invalid_oracle_context, _reason}),
    do: {:invalid_transition, :invalid_context}

  defp normalize_request_error({:invalid_context, _reason}),
    do: {:invalid_transition, :invalid_context}

  defp normalize_request_error(:missing_context), do: {:invalid_transition, :missing_context}

  defp normalize_request_error(other),
    do: {:invalid_transition, {:request_scope_change_error, other}}

  defp annotate_context(action, context, scope) do
    action
    |> Map.put(:context, context)
    |> Map.put(:scope, scope)
  end

  defp emit_telemetry(actions, opts) do
    dashboard_product = Keyword.get(opts, :dashboard_product, :unknown)

    Enum.each(actions, fn action ->
      Telemetry.emit_for_action(Map.put_new(action, :dashboard_product, dashboard_product))
    end)
  end
end
