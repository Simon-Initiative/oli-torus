defmodule Oli.Dashboard.LiveDataCoordinator.State do
  @moduledoc """
  Deterministic session-scoped state and transition helpers for coordinator request control.
  """

  alias Oli.Dashboard.LiveDataCoordinator.Actions
  alias Oli.Dashboard.Scope

  @default_timeout_ms 30_000
  @default_scrub_window_ms 400
  @default_scrub_threshold 3
  @allowed_profile_keys [:required, :optional]

  @type request_token :: pos_integer()
  @type oracle_key :: atom() | String.t()
  @type lifecycle :: :idle | :in_flight
  @type token_state :: :active | :queued | :stale

  @type dependency_profile :: %{
          required(:required) => [oracle_key()],
          required(:optional) => [oracle_key()]
        }

  @type dependency_profile_input :: map() | keyword()

  @type request :: %{
          required(:request_token) => request_token(),
          required(:context) => map(),
          required(:scope) => Scope.t(),
          required(:dependency_profile) => dependency_profile(),
          required(:pending_required) => [oracle_key()],
          required(:started_at_ms) => non_neg_integer()
        }

  @type transition_error ::
          {:invalid_scope, term()}
          | {:invalid_context, term()}
          | {:invalid_dependency_profile, term()}
          | {:invalid_oracle_misses, term()}
          | {:invalid_request_token, term()}
          | {:invalid_oracle_key, term()}
          | {:invalid_oracle_result, term()}
          | {:invalid_transition, term()}

  @type transition_result ::
          {:ok, t(), [Actions.t()]}
          | {:error, transition_error(), t(), [Actions.t()]}

  @enforce_keys [
    :lifecycle,
    :active_request,
    :queued_request,
    :retired_requests,
    :next_request_token,
    :timeout_ms,
    :scrub_window_ms,
    :scrub_threshold,
    :nav_burst_started_at_ms,
    :nav_burst_count
  ]
  defstruct [
    :lifecycle,
    :active_request,
    :queued_request,
    :retired_requests,
    :next_request_token,
    :timeout_ms,
    :scrub_window_ms,
    :scrub_threshold,
    :nav_burst_started_at_ms,
    :nav_burst_count
  ]

  @type t :: %__MODULE__{
          lifecycle: lifecycle(),
          active_request: request() | nil,
          queued_request: request() | nil,
          retired_requests: %{optional(request_token()) => request()},
          next_request_token: request_token(),
          timeout_ms: pos_integer(),
          scrub_window_ms: pos_integer(),
          scrub_threshold: pos_integer(),
          nav_burst_started_at_ms: non_neg_integer() | nil,
          nav_burst_count: non_neg_integer()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    timeout_ms = configured_timeout_ms(opts)
    scrub_window_ms = configured_scrub_window_ms(opts)
    scrub_threshold = configured_scrub_threshold(opts)

    %__MODULE__{
      lifecycle: :idle,
      active_request: nil,
      queued_request: nil,
      retired_requests: %{},
      next_request_token: 1,
      timeout_ms: timeout_ms,
      scrub_window_ms: scrub_window_ms,
      scrub_threshold: scrub_threshold,
      nav_burst_started_at_ms: nil,
      nav_burst_count: 0
    }
  end

  @spec idle?(t()) :: boolean()
  def idle?(%__MODULE__{lifecycle: :idle}), do: true
  def idle?(%__MODULE__{}), do: false

  @spec in_flight?(t()) :: boolean()
  def in_flight?(%__MODULE__{lifecycle: :in_flight}), do: true
  def in_flight?(%__MODULE__{}), do: false

  @spec queued?(t()) :: boolean()
  def queued?(%__MODULE__{queued_request: nil}), do: false
  def queued?(%__MODULE__{}), do: true

  @spec request_scope_change(t(), Scope.input(), dependency_profile_input(), map() | keyword()) ::
          transition_result()
  def request_scope_change(
        %__MODULE__{} = state,
        scope_input,
        dependency_profile_input,
        context_input
      ) do
    with {:ok, scope} <- Scope.new(scope_input),
         {:ok, dependency_profile} <- normalize_dependency_profile(dependency_profile_input),
         {:ok, context} <- normalize_context(context_input) do
      {state_with_burst, scrub_mode?} = track_navigation_burst(state)
      dispatch_scope_change(state_with_burst, context, scope, dependency_profile, scrub_mode?)
    else
      {:error, reason} ->
        transition_error(state, reason)
    end
  end

  def request_scope_change(state, _scope_input, _dependency_profile_input, _context_input) do
    invalid_state_transition(state)
  end

  @spec handle_oracle_result(t(), request_token(), oracle_key(), map()) :: transition_result()
  def handle_oracle_result(%__MODULE__{} = state, request_token, oracle_key, oracle_result) do
    with {:ok, normalized_request_token} <- normalize_request_token(request_token),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(oracle_key),
         {:ok, normalized_oracle_result} <- normalize_oracle_result(oracle_result),
         {:ok, token_state, request} <- request_for_token(state, normalized_request_token) do
      transition_oracle_result(
        state,
        token_state,
        request,
        normalized_request_token,
        normalized_oracle_key,
        normalized_oracle_result
      )
    else
      {:error, reason} ->
        transition_error(state, reason)
    end
  end

  def handle_oracle_result(state, _request_token, _oracle_key, _oracle_result) do
    invalid_state_transition(state)
  end

  @spec handle_timeout(t(), request_token()) :: transition_result()
  def handle_timeout(%__MODULE__{} = state, request_token) do
    with {:ok, normalized_request_token} <- normalize_request_token(request_token),
         {:ok, :active, request} <- request_for_token(state, normalized_request_token) do
      timeout_actions =
        [
          Actions.timeout_fired(normalized_request_token),
          Actions.emit_timeout_fallback(normalized_request_token, request.pending_required)
          | timeout_failure_actions(normalized_request_token, request.pending_required)
        ]

      {next_state, completion_actions} =
        complete_timed_out_request(state, normalized_request_token)
        |> case do
          {:ok, completed_state, actions} -> {completed_state, actions}
          {:error, _reason, returned_state, actions} -> {returned_state, actions}
        end

      {:ok, next_state, timeout_actions ++ completion_actions}
    else
      {:error, reason} ->
        transition_error(state, reason)
    end
  end

  def handle_timeout(state, _request_token) do
    invalid_state_transition(state)
  end

  @spec register_required_misses(t(), request_token(), [oracle_key()]) :: transition_result()
  def register_required_misses(%__MODULE__{} = state, request_token, misses) do
    with {:ok, normalized_request_token} <- normalize_request_token(request_token),
         {:ok, normalized_misses} <- normalize_oracle_keys(misses, :required),
         {:ok, :active, request} <- request_for_token(state, normalized_request_token) do
      updated_request = %{request | pending_required: normalized_misses}
      state_with_pending = %{state | active_request: updated_request}

      maybe_complete_active_request(state_with_pending, normalized_request_token)
    else
      {:error, reason} ->
        transition_error(state, reason)
    end
  end

  def register_required_misses(state, _request_token, _misses) do
    invalid_state_transition(state)
  end

  @spec request_for_token(t(), request_token()) ::
          {:ok, token_state(), request()} | {:error, transition_error()}
  def request_for_token(%__MODULE__{} = state, request_token) do
    resolve_request_for_token(state, request_token)
  end

  def request_for_token(state, _request_token) do
    {:error, {:invalid_transition, {:invalid_state, state}}}
  end

  defp dispatch_scope_change(
         %__MODULE__{lifecycle: :idle} = state,
         context,
         scope,
         dependency_profile,
         _scrub_mode?
       ) do
    request = build_request(state.next_request_token, context, scope, dependency_profile)

    next_state = %{
      state
      | lifecycle: :in_flight,
        active_request: request,
        queued_request: nil,
        next_request_token: state.next_request_token + 1
    }

    {:ok, next_state,
     [
       Actions.request_started(request),
       Actions.timeout_scheduled(request.request_token, state.timeout_ms)
     ]}
  end

  defp dispatch_scope_change(
         %__MODULE__{lifecycle: :in_flight} = state,
         context,
         scope,
         dependency_profile,
         false
       ) do
    request = build_request(state.next_request_token, context, scope, dependency_profile)
    replaced_request = state.active_request

    next_state = %{
      retire_request(state, replaced_request)
      | active_request: request,
        queued_request: nil,
        next_request_token: state.next_request_token + 1
    }

    {:ok, next_state,
     [
       Actions.timeout_cancelled(replaced_request.request_token),
       Actions.request_started(request),
       Actions.timeout_scheduled(request.request_token, state.timeout_ms)
     ]}
  end

  defp dispatch_scope_change(
         %__MODULE__{lifecycle: :in_flight, queued_request: nil} = state,
         context,
         scope,
         dependency_profile,
         true
       ) do
    request = build_request(state.next_request_token, context, scope, dependency_profile)

    next_state = %{
      state
      | queued_request: request,
        next_request_token: state.next_request_token + 1
    }

    {:ok, next_state, [Actions.request_queued(request)]}
  end

  defp dispatch_scope_change(
         %__MODULE__{lifecycle: :in_flight, queued_request: queued_request} = state,
         context,
         scope,
         dependency_profile,
         _scrub_mode?
       ) do
    request = build_request(state.next_request_token, context, scope, dependency_profile)

    next_state = %{
      state
      | queued_request: request,
        next_request_token: state.next_request_token + 1
    }

    {:ok, next_state, [Actions.request_queue_replaced(queued_request.request_token, request)]}
  end

  defp build_request(request_token, context, scope, dependency_profile) do
    %{
      request_token: request_token,
      context: context,
      scope: scope,
      dependency_profile: dependency_profile,
      pending_required: dependency_profile.required,
      started_at_ms: monotonic_now_ms()
    }
  end

  defp transition_oracle_result(
         state,
         :active,
         request,
         request_token,
         oracle_key,
         oracle_result
       ) do
    state_with_resolution = resolve_required_oracle(state, request, oracle_key)

    result_actions =
      [
        Actions.oracle_result_received(:active, request_token, oracle_key, oracle_result),
        result_action(request_token, oracle_key, oracle_result)
      ]
      |> Enum.reject(&is_nil/1)

    {next_state, completion_actions} =
      maybe_complete_active_request(state_with_resolution, request_token)
      |> case do
        {:ok, completed_state, actions} -> {completed_state, actions}
        {:error, _reason, returned_state, actions} -> {returned_state, actions}
      end

    {:ok, next_state, result_actions ++ completion_actions}
  end

  defp transition_oracle_result(
         state,
         :stale,
         request,
         request_token,
         oracle_key,
         oracle_result
       ) do
    {:ok, state,
     [
       Actions.oracle_result_received(:stale, request_token, oracle_key, oracle_result),
       Actions.stale_result_suppressed(
         request_token,
         oracle_key,
         context: request.context,
         scope: request.scope
       )
     ]}
  end

  defp transition_oracle_result(
         state,
         :queued,
         _request,
         request_token,
         _oracle_key,
         _oracle_result
       ) do
    transition_error(state, {:invalid_transition, {:queued_result_not_allowed, request_token}})
  end

  defp resolve_required_oracle(state, request, oracle_key) do
    if required_oracle?(request, oracle_key) do
      updated_request = %{
        request
        | pending_required: Enum.reject(request.pending_required, &(&1 == oracle_key))
      }

      %{state | active_request: updated_request}
    else
      state
    end
  end

  defp result_action(request_token, oracle_key, oracle_result) do
    case outcome_from_oracle_result(oracle_result) do
      {:ok, payload} -> Actions.emit_oracle_ready(request_token, oracle_key, payload)
      {:error, reason} -> Actions.emit_failure(request_token, oracle_key, reason)
    end
  end

  defp maybe_complete_active_request(
         %__MODULE__{active_request: %{request_token: request_token, pending_required: []}} =
           state,
         request_token
       ) do
    complete_active_request(state, request_token)
  end

  defp maybe_complete_active_request(%__MODULE__{} = state, _request_token) do
    {:ok, state, []}
  end

  defp complete_active_request(
         %__MODULE__{active_request: %{request_token: request_token, pending_required: []}} =
           state,
         request_token
       ) do
    active_request = state.active_request
    duration_ms = request_duration_ms(active_request)
    state_with_retired = retire_active_request(state)

    completion_actions = [
      Actions.timeout_cancelled(request_token),
      Actions.request_completed(
        request_token,
        duration_ms: duration_ms,
        completion_outcome: :success,
        context: active_request.context,
        scope: active_request.scope
      )
    ]

    case state_with_retired.queued_request do
      nil ->
        next_state = %{
          state_with_retired
          | lifecycle: :idle,
            active_request: nil,
            queued_request: nil
        }

        {:ok, next_state, completion_actions}

      promoted_request ->
        active_promoted_request = activate_promoted_request(promoted_request)

        next_state = %{
          state_with_retired
          | lifecycle: :in_flight,
            active_request: active_promoted_request,
            queued_request: nil
        }

        {:ok, next_state,
         completion_actions ++
           [
             Actions.request_promoted(active_promoted_request),
             Actions.timeout_scheduled(active_promoted_request.request_token, state.timeout_ms)
           ]}
    end
  end

  defp complete_active_request(%__MODULE__{} = state, request_token) do
    transition_error(state, {:invalid_transition, {:active_request_incomplete, request_token}})
  end

  defp complete_timed_out_request(
         %__MODULE__{active_request: %{request_token: request_token}} = state,
         request_token
       ) do
    active_request = state.active_request
    duration_ms = request_duration_ms(active_request)
    state_with_retired = retire_active_request(state)

    completion_actions = [
      Actions.request_timed_out(
        request_token,
        duration_ms: duration_ms,
        context: active_request.context,
        scope: active_request.scope
      )
    ]

    case state_with_retired.queued_request do
      nil ->
        next_state = %{
          state_with_retired
          | lifecycle: :idle,
            active_request: nil,
            queued_request: nil
        }

        {:ok, next_state, completion_actions}

      promoted_request ->
        active_promoted_request = activate_promoted_request(promoted_request)

        next_state = %{
          state_with_retired
          | lifecycle: :in_flight,
            active_request: active_promoted_request,
            queued_request: nil
        }

        {:ok, next_state,
         completion_actions ++
           [
             Actions.request_promoted(active_promoted_request),
             Actions.timeout_scheduled(active_promoted_request.request_token, state.timeout_ms)
           ]}
    end
  end

  defp complete_timed_out_request(%__MODULE__{} = state, request_token) do
    transition_error(state, {:invalid_transition, {:unknown_request_token, request_token}})
  end

  defp retire_active_request(%__MODULE__{active_request: active_request} = state) do
    retire_request(state, active_request)
  end

  defp retire_request(state, nil), do: state

  defp retire_request(state, request) do
    %{state | retired_requests: Map.put(state.retired_requests, request.request_token, request)}
  end

  defp resolve_request_for_token(
         %__MODULE__{active_request: %{request_token: request_token} = request},
         request_token
       ) do
    {:ok, :active, request}
  end

  defp resolve_request_for_token(
         %__MODULE__{queued_request: %{request_token: request_token} = request},
         request_token
       ) do
    {:ok, :queued, request}
  end

  defp resolve_request_for_token(%__MODULE__{retired_requests: retired_requests}, request_token) do
    case Map.fetch(retired_requests, request_token) do
      {:ok, request} -> {:ok, :stale, request}
      :error -> {:error, {:invalid_transition, {:unknown_request_token, request_token}}}
    end
  end

  defp required_oracle?(request, oracle_key) do
    Enum.member?(request.dependency_profile.required, oracle_key)
  end

  defp activate_promoted_request(request) do
    %{request | started_at_ms: monotonic_now_ms()}
  end

  defp request_duration_ms(request) do
    now = monotonic_now_ms()
    started_at_ms = Map.get(request, :started_at_ms, now)
    max(now - started_at_ms, 0)
  end

  defp timeout_failure_actions(request_token, pending_required) do
    Enum.map(pending_required, fn oracle_key ->
      Actions.emit_failure(request_token, oracle_key, :timeout)
    end)
  end

  defp outcome_from_oracle_result(%{status: :error} = oracle_result) do
    {:error, Map.get(oracle_result, :reason, :oracle_error)}
  end

  defp outcome_from_oracle_result(%{status: :ok, payload: payload}) when is_map(payload) do
    {:ok, payload}
  end

  defp outcome_from_oracle_result(%{status: :ok, payload: payload}) do
    {:error, {:invalid_payload, payload}}
  end

  defp outcome_from_oracle_result(%{} = oracle_result) do
    case Map.fetch(oracle_result, :payload) do
      {:ok, payload} when is_map(payload) ->
        {:ok, payload}

      {:ok, payload} ->
        {:error, {:invalid_payload, payload}}

      :error ->
        {:ok, oracle_result}
    end
  end

  defp normalize_dependency_profile(dependency_profile_input)
       when is_map(dependency_profile_input) or is_list(dependency_profile_input) do
    dependency_profile_map =
      case dependency_profile_input do
        value when is_list(value) -> Map.new(value)
        value -> value
      end

    with {:ok, attrs} <- normalize_profile_keys(dependency_profile_map),
         {:ok, required} <- normalize_oracle_keys(Map.get(attrs, :required, []), :required),
         {:ok, optional} <- normalize_oracle_keys(Map.get(attrs, :optional, []), :optional) do
      {:ok, %{required: required, optional: optional}}
    end
  end

  defp normalize_dependency_profile(other) do
    {:error, {:invalid_dependency_profile, {:invalid_payload, other}}}
  end

  defp normalize_profile_keys(attrs) do
    Enum.reduce(attrs, {:ok, %{}, []}, fn {raw_key, value}, {:ok, normalized, unknown} ->
      case normalize_profile_key(raw_key) do
        {:ok, key} -> {:ok, Map.put(normalized, key, value), unknown}
        :error -> {:ok, normalized, [raw_key | unknown]}
      end
    end)
    |> case do
      {:ok, normalized, []} ->
        {:ok, normalized}

      {:ok, _normalized, unknown} ->
        normalized_unknown =
          unknown
          |> Enum.map(fn key ->
            case normalize_profile_key(key) do
              {:ok, normalized_key} -> normalized_key
              :error -> key
            end
          end)
          |> Enum.sort()

        {:error, {:invalid_dependency_profile, {:unknown_fields, normalized_unknown}}}
    end
  end

  defp normalize_profile_key(key) when key in @allowed_profile_keys, do: {:ok, key}
  defp normalize_profile_key("required"), do: {:ok, :required}
  defp normalize_profile_key("optional"), do: {:ok, :optional}
  defp normalize_profile_key(_), do: :error

  defp normalize_oracle_keys(values, field) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case normalize_oracle_key(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, reversed |> Enum.reverse() |> Enum.uniq()}
      {:error, reason} -> {:error, {:invalid_dependency_profile, {field, reason}}}
    end
  end

  defp normalize_oracle_keys(other, field) do
    {:error, {:invalid_dependency_profile, {:invalid_oracle_key_list, field, other}}}
  end

  defp normalize_context(context) when is_map(context), do: {:ok, context}
  defp normalize_context(context) when is_list(context), do: {:ok, Map.new(context)}
  defp normalize_context(other), do: {:error, {:invalid_context, other}}

  defp normalize_request_token(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp normalize_request_token(value), do: {:error, {:invalid_request_token, value}}

  defp normalize_oracle_key(value) when is_atom(value), do: {:ok, value}

  defp normalize_oracle_key(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_oracle_key(value), do: {:error, {:invalid_oracle_key, value}}

  defp normalize_oracle_result(%{} = oracle_result), do: {:ok, oracle_result}
  defp normalize_oracle_result(other), do: {:error, {:invalid_oracle_result, other}}

  defp transition_error(state, reason) do
    normalized_reason = normalize_transition_error(reason)
    {:error, normalized_reason, state, [Actions.invalid_transition(normalized_reason)]}
  end

  defp normalize_transition_error({:invalid_scope, _} = error), do: error
  defp normalize_transition_error({:invalid_context, _} = error), do: error
  defp normalize_transition_error({:invalid_dependency_profile, _} = error), do: error
  defp normalize_transition_error({:invalid_oracle_misses, _} = error), do: error
  defp normalize_transition_error({:invalid_request_token, _} = error), do: error
  defp normalize_transition_error({:invalid_oracle_key, _} = error), do: error
  defp normalize_transition_error({:invalid_oracle_result, _} = error), do: error
  defp normalize_transition_error({:invalid_transition, _} = error), do: error
  defp normalize_transition_error(other), do: {:invalid_transition, {:unexpected_error, other}}

  defp configured_timeout_ms(opts) do
    case Keyword.get(opts, :timeout_ms) do
      value when is_integer(value) and value > 0 ->
        value

      _ ->
        read_timeout_ms_from_config()
    end
  end

  defp configured_scrub_window_ms(opts) do
    case Keyword.get(opts, :scrub_window_ms) do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_scrub_window_ms
    end
  end

  defp configured_scrub_threshold(opts) do
    case Keyword.get(opts, :scrub_threshold) do
      value when is_integer(value) and value > 1 -> value
      _ -> @default_scrub_threshold
    end
  end

  defp track_navigation_burst(state) do
    now = monotonic_now_ms()

    {started_at_ms, count} =
      case state.nav_burst_started_at_ms do
        nil ->
          {now, 1}

        started_at_ms when now - started_at_ms <= state.scrub_window_ms ->
          {started_at_ms, state.nav_burst_count + 1}

        _stale_started_at_ms ->
          {now, 1}
      end

    next_state = %{
      state
      | nav_burst_started_at_ms: started_at_ms,
        nav_burst_count: count
    }

    {next_state, count >= state.scrub_threshold}
  end

  defp read_timeout_ms_from_config do
    module_config = Application.get_env(:oli, Oli.Dashboard.LiveDataCoordinator, %{})

    configured =
      cond do
        is_map(module_config) ->
          Map.get(module_config, :timeout_ms)

        is_list(module_config) ->
          Keyword.get(module_config, :timeout_ms)

        true ->
          nil
      end

    case configured do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_timeout_ms
    end
  end

  defp invalid_state_transition(state) do
    reason = {:invalid_transition, {:invalid_state, state}}
    {:error, reason, new(), [Actions.invalid_transition(reason)]}
  end

  defp monotonic_now_ms do
    System.monotonic_time(:millisecond)
  end
end
