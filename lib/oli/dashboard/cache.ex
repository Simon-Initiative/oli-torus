defmodule Oli.Dashboard.Cache do
  @moduledoc """
  Stable cache facade for dashboard cache lookups and writes.

  This module is intentionally storage/policy focused. It must not implement:

  - request queueing
  - request token generation
  - stale-result suppression policy

  Those orchestration responsibilities stay in `Oli.Dashboard.LiveDataCoordinator`.
  """

  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.MissCoalescer
  alias Oli.Dashboard.Cache.Telemetry
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.RevisitCache
  alias Oli.Dashboard.Scope

  @typedoc "Canonical cache oracle identifier."
  @type oracle_key :: atom() | String.t()

  @typedoc "Version metadata used by deterministic cache keys."
  @type version :: non_neg_integer() | String.t()

  @typedoc "Key metadata required for deterministic keying."
  @type key_meta :: %{
          required(:oracle_version) => version(),
          required(:data_version) => version(),
          optional(:user_id) => pos_integer()
        }

  @typedoc "Result returned from required lookup APIs."
  @type lookup_result :: %{
          required(:hits) => %{optional(oracle_key()) => map()},
          required(:misses) => [oracle_key()],
          required(:source) => :inprocess | :revisit | :mixed | :none
        }

  @typedoc "Miss coalescing build function."
  @type build_fun :: (-> {:ok, map()} | {:error, term()} | map())

  @typedoc "Cache identity error."
  @type error ::
          {:invalid_oracle_keys, term()}
          | {:invalid_user_id, term()}
          | Key.error()
          | {:invalid_build_fun, term()}
          | {:invalid_payload, term()}
          | {:identity_guard_rejected, atom()}
          | {:cache_not_ready, atom()}

  @doc """
  Explicit boundary declarations used by boundary tests.
  """
  @spec boundary_non_goals() :: [atom()]
  def boundary_non_goals do
    [:request_queueing, :token_generation, :stale_result_suppression]
  end

  @doc """
  Looks up required oracle keys from cache tiers.

  In-process cache is the primary source for required lookup in Phase 2.
  When the in-process store is unavailable, this degrades to miss/fallback semantics.
  """
  @spec lookup_required(OracleContext.input(), Scope.input(), [oracle_key()], keyword()) ::
          {:ok, lookup_result()} | {:error, error()}
  def lookup_required(context_input, container_input, required_oracle_keys, opts \\ []) do
    with {:ok, context} <- OracleContext.new(context_input),
         {:ok, scope} <- Scope.new(container_input),
         {:ok, oracle_keys} <- normalize_oracle_keys(required_oracle_keys) do
      case resolve_inprocess_store(opts) do
        {:ok, inprocess_store} ->
          with {:ok, required_keys} <- build_required_keys(context, scope, oracle_keys, opts),
               {:ok, %{hits: key_hits, expired: expired_keys}} <-
                 lookup_required_in_store(inprocess_store, required_keys, opts),
               {:ok, hits} <- map_hits_to_oracle_keys(key_hits) do
            misses = misses_for_oracle_keys(oracle_keys, hits)
            source = lookup_source(:inprocess, hits, misses)
            outcome = lookup_outcome(source)

            Telemetry.lookup_stop(
              %{duration_ms: 0},
              %{
                cache_tier: :inprocess,
                outcome: outcome,
                container_type: scope.container_type,
                dashboard_context_type: context.dashboard_context_type,
                oracle_key_count: length(oracle_keys),
                miss_count: length(misses),
                expired_count: length(expired_keys)
              }
            )

            {:ok, %{hits: hits, misses: misses, source: source}}
          else
            {:error, reason} = error ->
              Telemetry.lookup_stop(
                %{duration_ms: 0},
                %{
                  cache_tier: :inprocess,
                  outcome: :error,
                  container_type: scope.container_type,
                  dashboard_context_type: context.dashboard_context_type,
                  oracle_key_count: length(oracle_keys),
                  miss_count: length(oracle_keys),
                  error_type: error_class(reason)
                }
              )

              error
          end

        {:error, reason} ->
          Telemetry.lookup_stop(
            %{duration_ms: 0},
            %{
              cache_tier: :inprocess,
              outcome: :error,
              container_type: scope.container_type,
              dashboard_context_type: context.dashboard_context_type,
              oracle_key_count: length(oracle_keys),
              miss_count: length(oracle_keys),
              error_type: error_class(reason)
            }
          )

          {:ok, %{hits: %{}, misses: oracle_keys, source: :none}}
      end
    else
      {:error, reason} = error ->
        Telemetry.lookup_stop(
          %{duration_ms: 0},
          %{
            cache_tier: :inprocess,
            outcome: :error,
            error_type: error_class(reason)
          }
        )

        error
    end
  end

  @doc """
  Looks up revisit-eligible oracle keys for explicit-entry revisit flows.

  Revisit lookups are eligible on explicit-entry flows for top-level course scope
  and explicit container scope.
  When revisit cache is unavailable, this degrades to miss/fallback semantics.
  """
  @spec lookup_revisit(
          pos_integer(),
          OracleContext.input(),
          Scope.input(),
          [oracle_key()],
          keyword()
        ) ::
          {:ok, lookup_result()} | {:error, error()}
  def lookup_revisit(user_id, context_input, container_input, oracle_keys, opts \\ []) do
    with {:ok, normalized_user_id} <- normalize_user_id(user_id),
         {:ok, context} <- OracleContext.new(context_input),
         {:ok, scope} <- Scope.new(container_input),
         :ok <- ensure_user_matches_context(normalized_user_id, context),
         {:ok, normalized_oracle_keys} <- normalize_oracle_keys(oracle_keys) do
      if revisit_lookup_eligible?(scope, opts) do
        case resolve_revisit_cache(opts) do
          {:ok, revisit_cache} ->
            with {:ok, revisit_keys} <-
                   build_revisit_keys(
                     normalized_user_id,
                     context,
                     scope,
                     normalized_oracle_keys,
                     opts
                   ),
                 {:ok, %{hits: key_hits, expired: expired_keys}} <-
                   lookup_revisit_in_store(revisit_cache, revisit_keys, opts),
                 {:ok, hits} <- map_hits_to_oracle_keys(key_hits) do
              misses = misses_for_oracle_keys(normalized_oracle_keys, hits)
              source = lookup_source(:revisit, hits, misses)
              outcome = lookup_outcome(source)

              Telemetry.lookup_stop(
                %{duration_ms: 0},
                %{
                  cache_tier: :revisit,
                  outcome: outcome,
                  container_type: scope.container_type,
                  dashboard_context_type: context.dashboard_context_type,
                  oracle_key_count: length(normalized_oracle_keys),
                  miss_count: length(misses),
                  expired_count: length(expired_keys)
                }
              )

              {:ok, %{hits: hits, misses: misses, source: source}}
            else
              {:error, reason} ->
                Telemetry.lookup_stop(
                  %{duration_ms: 0},
                  %{
                    cache_tier: :revisit,
                    outcome: :error,
                    container_type: scope.container_type,
                    dashboard_context_type: context.dashboard_context_type,
                    oracle_key_count: length(normalized_oracle_keys),
                    miss_count: length(normalized_oracle_keys),
                    error_type: error_class(reason)
                  }
                )

                {:ok, %{hits: %{}, misses: normalized_oracle_keys, source: :none}}
            end

          {:error, reason} ->
            Telemetry.lookup_stop(
              %{duration_ms: 0},
              %{
                cache_tier: :revisit,
                outcome: :error,
                container_type: scope.container_type,
                dashboard_context_type: context.dashboard_context_type,
                oracle_key_count: length(normalized_oracle_keys),
                miss_count: length(normalized_oracle_keys),
                error_type: error_class(reason)
              }
            )

            {:ok, %{hits: %{}, misses: normalized_oracle_keys, source: :none}}
        end
      else
        Telemetry.lookup_stop(
          %{duration_ms: 0},
          %{
            cache_tier: :revisit,
            outcome: :skipped,
            container_type: scope.container_type,
            dashboard_context_type: context.dashboard_context_type,
            oracle_key_count: length(normalized_oracle_keys),
            miss_count: length(normalized_oracle_keys)
          }
        )

        {:ok, %{hits: %{}, misses: normalized_oracle_keys, source: :none}}
      end
    else
      {:error, reason} = error ->
        Telemetry.lookup_stop(
          %{duration_ms: 0},
          %{
            cache_tier: :revisit,
            outcome: :error,
            error_type: error_class(reason)
          }
        )

        error
    end
  end

  @doc """
  Writes a single oracle payload with deterministic identity/version guard checks.

  Phase 4 supports active and late writes, guarded by deterministic identity checks.
  """
  @spec write_oracle(
          OracleContext.input(),
          Scope.input(),
          oracle_key(),
          map(),
          key_meta(),
          keyword()
        ) :: :ok | {:error, error()}
  def write_oracle(context_input, container_input, oracle_key, payload, meta, opts \\ []) do
    with {:ok, context} <- OracleContext.new(context_input),
         {:ok, scope} <- Scope.new(container_input),
         {:ok, write_mode} <- determine_write_mode(scope, opts),
         :ok <- validate_write_identity(context, scope, meta, write_mode, opts),
         {:ok, key} <- Key.inprocess(context, scope, oracle_key, meta) do
      case resolve_inprocess_store(opts) do
        {:ok, inprocess_store} ->
          with {:ok, %{evicted_containers: _evicted_containers}} <-
                 write_oracle_to_store(inprocess_store, key, payload, opts) do
            Telemetry.write_stop(
              %{duration_ms: 0},
              %{
                cache_tier: :inprocess,
                outcome: :accepted,
                container_type: scope.container_type,
                oracle_key: oracle_key,
                write_mode: write_mode
              }
            )

            :ok
          else
            {:error, reason} = error ->
              Telemetry.write_stop(
                %{duration_ms: 0},
                %{
                  cache_tier: :inprocess,
                  outcome: :error,
                  container_type: scope.container_type,
                  oracle_key: oracle_key,
                  write_mode: write_mode,
                  error_type: error_class(reason)
                }
              )

              error
          end

        {:error, reason} = error ->
          Telemetry.write_stop(
            %{duration_ms: 0},
            %{
              cache_tier: :inprocess,
              outcome: :rejected,
              container_type: scope.container_type,
              oracle_key: oracle_key,
              write_mode: write_mode,
              error_type: error_class(reason)
            }
          )

          error
      end
    else
      {:error, reason} = error ->
        Telemetry.write_stop(
          %{duration_ms: 0},
          %{
            cache_tier: :inprocess,
            outcome:
              if(match?({:identity_guard_rejected, _}, reason), do: :rejected, else: :error),
            oracle_key: oracle_key,
            write_mode: write_mode_from_opts(opts),
            error_type: error_class(reason)
          }
        )

        error
    end
  end

  @doc """
  Marks a container as recently used for LRU policy bookkeeping.

  Phase 2 mutates recency in the in-process cache store when available.
  """
  @spec touch_container(OracleContext.input(), Scope.input(), keyword()) ::
          :ok | {:error, error()}
  def touch_container(context_input, container_input, opts \\ []) do
    with {:ok, context} <- OracleContext.new(context_input),
         {:ok, scope} <- Scope.new(container_input) do
      with {:ok, inprocess_store} <- resolve_inprocess_store(opts),
           {:ok, _result} <-
             touch_container_in_store(
               inprocess_store,
               context.dashboard_context_id,
               scope.container_type,
               scope.container_id,
               opts
             ) do
        :ok
      end
    end
  end

  @doc """
  Coalesces identical cache misses so one builder path can serve waiters.

  Phase 4 uses node-local producer/waiter coalescing when configured and
  degrades to non-coalesced builder execution on coalescer failures/timeouts.
  """
  @spec coalesce_or_build(Key.cache_key(), build_fun(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def coalesce_or_build(cache_key, build_fun, opts \\ [])

  def coalesce_or_build(cache_key, build_fun, opts) when is_function(build_fun, 0) do
    case resolve_miss_coalescer(opts) do
      {:ok, coalescer} ->
        case claim_coalesced(coalescer, cache_key) do
          {:producer, _claim_ref} ->
            Telemetry.coalescing_claim(%{outcome: :coalesced_producer})
            run_as_coalesced_producer(coalescer, cache_key, build_fun)

          {:waiter, wait_ref} ->
            Telemetry.coalescing_claim(%{outcome: :coalesced_waiter})
            await_as_coalesced_waiter(wait_ref, build_fun, opts)
        end

      {:error, reason} ->
        Telemetry.coalescing_claim(%{
          outcome: :coalescer_fallback,
          error_type: error_class(reason)
        })

        normalize_builder_result(build_fun.())
    end
  end

  def coalesce_or_build(_cache_key, build_fun, _opts) do
    {:error, {:invalid_build_fun, build_fun}}
  end

  defp resolve_inprocess_store(opts) do
    case Keyword.get(opts, :inprocess_store) do
      store when is_pid(store) -> {:ok, store}
      store when is_atom(store) and not is_nil(store) -> {:ok, store}
      _ -> {:error, {:cache_not_ready, :inprocess_store}}
    end
  end

  defp resolve_revisit_cache(opts) do
    case Keyword.get(opts, :revisit_cache) do
      store when is_pid(store) -> {:ok, store}
      store when is_atom(store) and not is_nil(store) -> {:ok, store}
      _ -> {:error, {:cache_not_ready, :revisit_cache}}
    end
  end

  defp resolve_miss_coalescer(opts) do
    case Keyword.get(opts, :miss_coalescer) do
      coalescer when is_pid(coalescer) -> {:ok, coalescer}
      coalescer when is_atom(coalescer) and not is_nil(coalescer) -> {:ok, coalescer}
      _ -> {:error, {:cache_not_ready, :miss_coalescer}}
    end
  end

  defp lookup_required_in_store(inprocess_store, required_keys, opts) do
    try do
      InProcessStore.lookup_required(inprocess_store, required_keys, opts)
    catch
      :exit, _ -> {:error, {:cache_not_ready, :inprocess_store}}
    end
  end

  defp lookup_revisit_in_store(revisit_cache, revisit_keys, opts) do
    try do
      RevisitCache.lookup(revisit_cache, revisit_keys, opts)
    catch
      :exit, _ -> {:error, {:cache_not_ready, :revisit_cache}}
    end
  end

  defp write_oracle_to_store(inprocess_store, key, payload, opts) do
    try do
      InProcessStore.write_oracle(inprocess_store, key, payload, opts)
    catch
      :exit, _ -> {:error, {:cache_not_ready, :inprocess_store}}
    end
  end

  defp touch_container_in_store(inprocess_store, context_id, container_type, container_id, opts) do
    try do
      InProcessStore.touch_container(
        inprocess_store,
        context_id,
        container_type,
        container_id,
        opts
      )
    catch
      :exit, _ -> {:error, {:cache_not_ready, :inprocess_store}}
    end
  end

  defp claim_coalesced(coalescer, cache_key) do
    try do
      MissCoalescer.claim(coalescer, cache_key)
    catch
      :exit, _ -> {:producer, make_ref()}
    end
  end

  defp run_as_coalesced_producer(coalescer, cache_key, build_fun) do
    result = normalize_builder_result(build_fun.())

    try do
      :ok = MissCoalescer.publish(coalescer, cache_key, result)
    catch
      :exit, _ -> :ok
    end

    result
  end

  defp await_as_coalesced_waiter(wait_ref, build_fun, opts) do
    timeout_ms = Keyword.get(opts, :coalescer_timeout_ms, 5_000)

    case MissCoalescer.await(wait_ref, timeout_ms) do
      {:ok, _} = ok ->
        ok

      {:error, :coalescer_timeout} ->
        Telemetry.coalescing_claim(%{
          outcome: :coalescer_fallback,
          error_type: :coalescer_timeout
        })

        normalize_builder_result(build_fun.())

      {:error, {:coalescer_producer_down, reason}} ->
        Telemetry.coalescing_claim(%{
          outcome: :coalescer_fallback,
          error_type: error_class(reason)
        })

        normalize_builder_result(build_fun.())

      {:error, reason} ->
        Telemetry.coalescing_claim(%{
          outcome: :coalescer_error,
          error_type: error_class(reason)
        })

        {:error, reason}
    end
  end

  defp build_required_keys(context, scope, oracle_keys, opts) do
    Enum.reduce_while(oracle_keys, {:ok, []}, fn oracle_key, {:ok, acc} ->
      meta = key_meta_for_oracle(opts, oracle_key)

      case Key.inprocess(context, scope, oracle_key, meta) do
        {:ok, key} -> {:cont, {:ok, [key | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed_keys} -> {:ok, Enum.reverse(reversed_keys)}
      {:error, _} = error -> error
    end
  end

  defp build_revisit_keys(user_id, context, scope, oracle_keys, opts) do
    Enum.reduce_while(oracle_keys, {:ok, []}, fn oracle_key, {:ok, acc} ->
      meta = key_meta_for_oracle(opts, oracle_key)

      case Key.revisit(user_id, context, scope, oracle_key, meta) do
        {:ok, key} -> {:cont, {:ok, [key | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed_keys} -> {:ok, Enum.reverse(reversed_keys)}
      {:error, _} = error -> error
    end
  end

  defp key_meta_for_oracle(opts, oracle_key) do
    default_meta = Keyword.get(opts, :key_meta, %{oracle_version: 1, data_version: 1})
    key_meta_by_oracle = Keyword.get(opts, :key_meta_by_oracle, %{}) |> normalize_meta_map()

    case Map.get(key_meta_by_oracle, oracle_key) ||
           Map.get(key_meta_by_oracle, oracle_key_alias(oracle_key)) do
      nil -> default_meta
      meta -> meta
    end
  end

  defp normalize_meta_map(meta_map) when is_map(meta_map), do: meta_map
  defp normalize_meta_map(meta_map) when is_list(meta_map), do: Map.new(meta_map)
  defp normalize_meta_map(_), do: %{}

  defp oracle_key_alias(key) when is_atom(key), do: Atom.to_string(key)
  defp oracle_key_alias(key), do: key

  defp map_hits_to_oracle_keys(key_hits) do
    Enum.reduce_while(key_hits, {:ok, %{}}, fn {cache_key, payload}, {:ok, hits_acc} ->
      case Key.parse(cache_key) do
        {:ok, %{oracle_key: oracle_key}} ->
          {:cont, {:ok, Map.put(hits_acc, oracle_key, payload)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp misses_for_oracle_keys(oracle_keys, hits) do
    Enum.reduce(oracle_keys, [], fn oracle_key, misses ->
      if Map.has_key?(hits, oracle_key) do
        misses
      else
        [oracle_key | misses]
      end
    end)
    |> Enum.reverse()
  end

  defp lookup_source(cache_tier, hits, misses) do
    case {map_size(hits), length(misses)} do
      {0, _} -> :none
      {_hit_count, 0} -> cache_tier
      {_hit_count, _miss_count} -> :mixed
    end
  end

  defp lookup_outcome(:inprocess), do: :hit
  defp lookup_outcome(:revisit), do: :hit
  defp lookup_outcome(:mixed), do: :partial
  defp lookup_outcome(:none), do: :miss
  defp lookup_outcome(_), do: :error

  defp revisit_lookup_eligible?(scope, opts) do
    explicit_entry? =
      Keyword.get(opts, :revisit_eligible, false) or
        Keyword.get(opts, :explicit_container_entry, false) or
        Keyword.get(opts, :entry_mode) == :explicit_container

    explicit_entry? and
      ((scope.container_type == :course and is_nil(scope.container_id)) or
         (scope.container_type == :container and is_integer(scope.container_id)))
  end

  defp ensure_user_matches_context(user_id, context) do
    if context.user_id == user_id do
      :ok
    else
      {:error, {:invalid_user_id, :context_mismatch}}
    end
  end

  defp determine_write_mode(scope, opts) do
    case Keyword.get(opts, :active_scope) do
      nil ->
        {:ok, :active}

      active_scope_input ->
        case Scope.new(active_scope_input) do
          {:ok, active_scope} ->
            if active_scope.container_type == scope.container_type and
                 active_scope.container_id == scope.container_id do
              {:ok, :active}
            else
              {:ok, :late}
            end

          {:error, _reason} ->
            {:error, {:identity_guard_rejected, :invalid_active_scope}}
        end
    end
  end

  defp validate_write_identity(context, scope, meta_input, write_mode, opts) do
    meta = normalize_meta_input(meta_input)

    with :ok <- validate_context_identity(context, meta),
         :ok <- validate_container_identity(scope, meta),
         :ok <- validate_late_write_policy(write_mode, opts) do
      :ok
    end
  end

  defp validate_context_identity(context, meta) do
    expected_context_id = Map.get(meta, :dashboard_context_id, context.dashboard_context_id)

    if expected_context_id == context.dashboard_context_id do
      :ok
    else
      {:error, {:identity_guard_rejected, :dashboard_context_mismatch}}
    end
  end

  defp validate_container_identity(scope, meta) do
    expected_container_type = Map.get(meta, :container_type, scope.container_type)
    expected_container_id = Map.get(meta, :container_id, scope.container_id)

    cond do
      expected_container_type != scope.container_type ->
        {:error, {:identity_guard_rejected, :container_type_mismatch}}

      expected_container_id != scope.container_id ->
        {:error, {:identity_guard_rejected, :container_id_mismatch}}

      true ->
        :ok
    end
  end

  defp validate_late_write_policy(:late, opts) do
    if Keyword.get(opts, :allow_late_write, true) do
      :ok
    else
      {:error, {:identity_guard_rejected, :late_write_disallowed}}
    end
  end

  defp validate_late_write_policy(:active, _opts), do: :ok

  defp write_mode_from_opts(opts) do
    case Keyword.get(opts, :active_scope) do
      nil -> :active
      _ -> :late
    end
  end

  defp normalize_meta_input(meta) when is_map(meta), do: meta
  defp normalize_meta_input(meta) when is_list(meta), do: Map.new(meta)
  defp normalize_meta_input(_), do: %{}

  defp normalize_user_id(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp normalize_user_id(value), do: {:error, {:invalid_user_id, value}}

  defp normalize_oracle_keys(keys) when is_list(keys) do
    keys
    |> Enum.reduce_while({:ok, []}, fn key, {:ok, acc} ->
      case normalize_oracle_key(key) do
        {:ok, normalized} ->
          {:cont, {:ok, [normalized | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_oracle_keys, reason}}}
      end
    end)
    |> case do
      {:ok, normalized_reversed} ->
        {:ok, normalized_reversed |> Enum.reverse() |> Enum.uniq()}

      {:error, _} = error ->
        error
    end
  end

  defp normalize_oracle_keys(other), do: {:error, {:invalid_oracle_keys, other}}

  defp normalize_oracle_key(key) when is_atom(key), do: {:ok, key}
  defp normalize_oracle_key(key) when is_binary(key) and byte_size(key) > 0, do: {:ok, key}
  defp normalize_oracle_key(key), do: {:error, {:invalid_oracle_key, key}}

  defp normalize_builder_result({:ok, payload} = ok) when is_map(payload), do: ok
  defp normalize_builder_result({:error, _reason} = error), do: error
  defp normalize_builder_result(payload) when is_map(payload), do: {:ok, payload}
  defp normalize_builder_result(other), do: {:error, {:invalid_builder_result, other}}

  defp error_class({reason, _detail}) when is_atom(reason), do: reason
  defp error_class({reason, _detail, _extra}) when is_atom(reason), do: reason
  defp error_class(reason) when is_atom(reason), do: reason
  defp error_class(_reason), do: :unknown
end
