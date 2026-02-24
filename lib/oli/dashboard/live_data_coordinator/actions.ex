defmodule Oli.Dashboard.LiveDataCoordinator.Actions do
  @moduledoc """
  Action envelope primitives emitted by coordinator state transitions.
  """

  alias Oli.Dashboard.Scope

  @type request_token :: pos_integer()
  @type oracle_key :: atom() | String.t()
  @type token_state :: :active | :queued | :stale
  @type cache_outcome :: :full_hit | :partial_hit | :miss | :error

  @type dependency_profile :: %{
          required(:required) => [oracle_key()],
          required(:optional) => [oracle_key()]
        }

  @type request :: %{
          required(:request_token) => request_token(),
          required(:context) => map(),
          required(:scope) => Scope.t(),
          required(:dependency_profile) => dependency_profile(),
          required(:pending_required) => [oracle_key()]
        }

  @type t :: %{
          required(:type) => atom(),
          optional(:request_token) => request_token(),
          optional(:context) => map(),
          optional(:scope) => Scope.t(),
          optional(:duration_ms) => non_neg_integer(),
          optional(:completion_outcome) => :success | :timeout | :unknown,
          optional(:dependency_profile) => dependency_profile(),
          optional(:cache_outcome) => cache_outcome(),
          optional(:cache_source) => atom(),
          optional(:hits) => %{optional(oracle_key()) => map()},
          optional(:misses) => [oracle_key()],
          optional(:oracle_key) => oracle_key(),
          optional(:oracle_result) => map(),
          optional(:payload) => map(),
          optional(:token_state) => token_state(),
          optional(:write_mode) => :active | :late,
          optional(:outcome) => atom(),
          optional(:replaced_request_token) => request_token(),
          optional(:timeout_ms) => pos_integer(),
          optional(:reason) => term()
        }

  @spec request_started(request()) :: t()
  def request_started(request) do
    %{
      type: :request_started,
      request_token: request.request_token,
      context: request.context,
      scope: request.scope,
      dependency_profile: request.dependency_profile
    }
  end

  @spec request_queued(request()) :: t()
  def request_queued(request) do
    %{
      type: :request_queued,
      request_token: request.request_token,
      context: request.context,
      scope: request.scope,
      dependency_profile: request.dependency_profile
    }
  end

  @spec request_queue_replaced(request_token(), request()) :: t()
  def request_queue_replaced(replaced_request_token, replacement_request) do
    %{
      type: :request_queue_replaced,
      request_token: replacement_request.request_token,
      replaced_request_token: replaced_request_token,
      context: replacement_request.context,
      scope: replacement_request.scope,
      dependency_profile: replacement_request.dependency_profile
    }
  end

  @spec timeout_scheduled(request_token(), pos_integer()) :: t()
  def timeout_scheduled(request_token, timeout_ms) do
    %{type: :timeout_scheduled, request_token: request_token, timeout_ms: timeout_ms}
  end

  @spec timeout_cancelled(request_token()) :: t()
  def timeout_cancelled(request_token) do
    %{type: :timeout_cancelled, request_token: request_token}
  end

  @spec request_timed_out(request_token(), keyword()) :: t()
  def request_timed_out(request_token, opts \\ []) do
    base = %{type: :request_timed_out, request_token: request_token}

    with_optional_completion_fields(
      base,
      Keyword.get(opts, :duration_ms),
      :timeout,
      Keyword.get(opts, :context),
      Keyword.get(opts, :scope)
    )
  end

  @spec emit_timeout_fallback(request_token(), [oracle_key()]) :: t()
  def emit_timeout_fallback(request_token, misses) do
    %{type: :emit_timeout_fallback, request_token: request_token, misses: misses}
  end

  @spec cache_consulted(request_token(), cache_outcome(), map(), [oracle_key()], atom()) :: t()
  def cache_consulted(request_token, cache_outcome, hits, misses, cache_source) do
    %{
      type: :cache_consulted,
      request_token: request_token,
      cache_outcome: cache_outcome,
      hits: hits,
      misses: misses,
      cache_source: cache_source
    }
  end

  @spec emit_required_ready(request_token(), map(), atom()) :: t()
  def emit_required_ready(request_token, hits, cache_source) do
    %{
      type: :emit_required_ready,
      request_token: request_token,
      hits: hits,
      cache_source: cache_source
    }
  end

  @spec emit_loading(request_token(), [oracle_key()]) :: t()
  def emit_loading(request_token, misses) do
    %{type: :emit_loading, request_token: request_token, misses: misses}
  end

  @spec runtime_start(request_token(), [oracle_key()]) :: t()
  def runtime_start(request_token, misses) do
    %{type: :runtime_start, request_token: request_token, misses: misses}
  end

  @spec oracle_result_received(token_state(), request_token(), oracle_key(), map()) :: t()
  def oracle_result_received(token_state, request_token, oracle_key, oracle_result) do
    %{
      type: :oracle_result_received,
      token_state: token_state,
      request_token: request_token,
      oracle_key: oracle_key,
      oracle_result: oracle_result
    }
  end

  @spec emit_oracle_ready(request_token(), oracle_key(), map()) :: t()
  def emit_oracle_ready(request_token, oracle_key, payload) do
    %{
      type: :emit_oracle_ready,
      request_token: request_token,
      oracle_key: oracle_key,
      payload: payload
    }
  end

  @spec emit_failure(request_token(), oracle_key(), term()) :: t()
  def emit_failure(request_token, oracle_key, reason) do
    %{type: :emit_failure, request_token: request_token, oracle_key: oracle_key, reason: reason}
  end

  @spec cache_write(
          request_token(),
          token_state(),
          oracle_key(),
          :active | :late,
          :accepted | :rejected | :error | :skipped,
          term()
        ) :: t()
  def cache_write(request_token, token_state, oracle_key, write_mode, outcome, reason \\ nil) do
    %{
      type: :cache_write,
      request_token: request_token,
      token_state: token_state,
      oracle_key: oracle_key,
      write_mode: write_mode,
      outcome: outcome,
      reason: reason
    }
  end

  @spec stale_result_suppressed(request_token(), oracle_key(), keyword()) :: t()
  def stale_result_suppressed(request_token, oracle_key, opts \\ []) do
    base = %{
      type: :stale_result_suppressed,
      request_token: request_token,
      oracle_key: oracle_key,
      token_state: :stale
    }

    base
    |> with_optional_context(Keyword.get(opts, :context))
    |> with_optional_scope(Keyword.get(opts, :scope))
  end

  @spec request_completed(request_token(), keyword()) :: t()
  def request_completed(request_token, opts \\ []) do
    base = %{type: :request_completed, request_token: request_token}

    with_optional_completion_fields(
      base,
      Keyword.get(opts, :duration_ms),
      Keyword.get(opts, :completion_outcome, :success),
      Keyword.get(opts, :context),
      Keyword.get(opts, :scope)
    )
  end

  @spec request_promoted(request()) :: t()
  def request_promoted(request) do
    %{
      type: :request_promoted,
      request_token: request.request_token,
      context: request.context,
      scope: request.scope,
      dependency_profile: request.dependency_profile
    }
  end

  @spec timeout_fired(request_token()) :: t()
  def timeout_fired(request_token) do
    %{type: :timeout_fired, request_token: request_token}
  end

  @spec invalid_transition(term()) :: t()
  def invalid_transition(reason) do
    %{type: :invalid_transition, reason: reason}
  end

  defp with_optional_completion_fields(action, duration_ms, completion_outcome, context, scope) do
    action
    |> with_optional_duration(duration_ms)
    |> Map.put(:completion_outcome, normalize_completion_outcome(completion_outcome))
    |> with_optional_context(context)
    |> with_optional_scope(scope)
  end

  defp with_optional_duration(action, duration_ms)
       when is_integer(duration_ms) and duration_ms >= 0 do
    Map.put(action, :duration_ms, duration_ms)
  end

  defp with_optional_duration(action, _), do: action

  defp with_optional_context(action, context) when is_map(context),
    do: Map.put(action, :context, context)

  defp with_optional_context(action, _), do: action

  defp with_optional_scope(action, %Scope{} = scope), do: Map.put(action, :scope, scope)
  defp with_optional_scope(action, _), do: action

  defp normalize_completion_outcome(:success), do: :success
  defp normalize_completion_outcome(:timeout), do: :timeout
  defp normalize_completion_outcome(_), do: :unknown
end
