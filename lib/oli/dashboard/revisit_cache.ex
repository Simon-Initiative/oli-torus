defmodule Oli.Dashboard.RevisitCache do
  @moduledoc """
  Node-local revisit cache store for explicit-container return flows.
  """

  use GenServer

  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.Policy
  alias Oli.Dashboard.Cache.Telemetry

  @type entry :: %{
          payload: map(),
          written_at_ms: non_neg_integer(),
          last_accessed_at_ms: non_neg_integer()
        }

  @type state :: %{
          entries: %{optional(Key.revisit_key()) => entry()},
          clock: (-> integer()),
          write_count: non_neg_integer()
        }

  @type error :: {:invalid_cache_key, term()} | {:invalid_payload, term()}

  @doc "Starts the revisit cache process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {start_opts, genserver_opts} = Keyword.split(opts, [:clock])
    GenServer.start_link(__MODULE__, start_opts, genserver_opts)
  end

  @doc "Looks up revisit cache keys and returns deterministic hits/misses."
  @spec lookup(GenServer.server(), [Key.revisit_key()], keyword()) ::
          {:ok, %{hits: map(), misses: [Key.revisit_key()], expired: [Key.revisit_key()]}}
          | {:error, error()}
  def lookup(cache, revisit_keys, opts \\ []) do
    GenServer.call(cache, {:lookup, revisit_keys, opts})
  end

  @doc "Writes one revisit cache key."
  @spec write(GenServer.server(), Key.revisit_key(), map(), keyword()) :: :ok | {:error, error()}
  def write(cache, revisit_key, payload, opts \\ []) do
    GenServer.call(cache, {:write, revisit_key, payload, opts})
  end

  @doc "Returns store snapshot for tests/diagnostics."
  @spec snapshot(GenServer.server()) :: {:ok, state()}
  def snapshot(cache), do: GenServer.call(cache, :snapshot)

  @impl true
  def init(opts) do
    clock =
      case Keyword.get(opts, :clock) do
        clock when is_function(clock, 0) -> clock
        _ -> fn -> System.monotonic_time(:millisecond) end
      end

    {:ok, %{entries: %{}, clock: clock, write_count: 0}}
  end

  @impl true
  def handle_call({:lookup, revisit_keys, opts}, _from, state) do
    with {:ok, _validated} <- validate_revisit_keys(revisit_keys) do
      ttl_ms = resolve_ttl_ms(opts)
      now_ms = now_ms(state)

      {hits, misses, expired, entries} =
        Enum.reduce(revisit_keys, {%{}, [], [], state.entries}, fn revisit_key,
                                                                   {hits_acc, misses_acc,
                                                                    expired_acc, entries_acc} ->
          case Map.get(entries_acc, revisit_key) do
            nil ->
              {hits_acc, [revisit_key | misses_acc], expired_acc, entries_acc}

            %{written_at_ms: written_at_ms, payload: payload} ->
              if expired?(written_at_ms, ttl_ms, now_ms) do
                {
                  hits_acc,
                  [revisit_key | misses_acc],
                  [revisit_key | expired_acc],
                  Map.delete(entries_acc, revisit_key)
                }
              else
                updated_entries =
                  Map.update!(entries_acc, revisit_key, fn entry ->
                    %{entry | last_accessed_at_ms: now_ms}
                  end)

                {Map.put(hits_acc, revisit_key, payload), misses_acc, expired_acc,
                 updated_entries}
              end
          end
        end)

      next_state = %{state | entries: entries}
      result = %{hits: hits, misses: Enum.reverse(misses), expired: Enum.reverse(expired)}

      {:reply, {:ok, result}, next_state}
    else
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:write, revisit_key, payload, opts}, _from, state) when is_map(payload) do
    with :ok <- validate_revisit_key(revisit_key) do
      now_ms = now_ms(state)
      write_count = state.write_count + 1

      entries_with_write =
        Map.put(state.entries, revisit_key, %{
          payload: payload,
          written_at_ms: now_ms,
          last_accessed_at_ms: now_ms
        })

      ttl_ms = resolve_ttl_ms(opts)
      sweep_interval = resolve_write_sweep_interval(opts)
      max_entries = resolve_max_entries(opts)

      {entries_after_prune, pruned_expired_count} =
        maybe_prune_expired_entries(
          entries_with_write,
          ttl_ms,
          now_ms,
          write_count,
          sweep_interval
        )

      {entries_after_cap, evicted_count} = enforce_entry_cap(entries_after_prune, max_entries)

      container_type = container_type_from_revisit_key(revisit_key)

      Telemetry.write_stop(
        %{duration_ms: 0},
        %{
          cache_tier: :revisit,
          outcome: :accepted,
          container_type: container_type,
          pruned_expired_count: pruned_expired_count,
          evicted_count: evicted_count,
          entry_count: map_size(entries_after_cap)
        }
      )

      {:reply, :ok, %{state | entries: entries_after_cap, write_count: write_count}}
    else
      {:error, reason} = error ->
        Telemetry.write_stop(
          %{duration_ms: 0},
          %{
            cache_tier: :revisit,
            outcome: :rejected,
            container_type: :unknown,
            error_type: error_class(reason)
          }
        )

        {:reply, error, state}
    end
  end

  def handle_call({:write, _revisit_key, payload, _opts}, _from, state) do
    Telemetry.write_stop(
      %{duration_ms: 0},
      %{
        cache_tier: :revisit,
        outcome: :rejected,
        container_type: :unknown,
        error_type: :invalid_payload
      }
    )

    {:reply, {:error, {:invalid_payload, payload}}, state}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, {:ok, state}, state}

  defp validate_revisit_keys(revisit_keys) when is_list(revisit_keys) do
    Enum.reduce_while(revisit_keys, {:ok, revisit_keys}, fn revisit_key, {:ok, _acc} ->
      case validate_revisit_key(revisit_key) do
        :ok -> {:cont, {:ok, revisit_keys}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_revisit_keys(other),
    do: {:error, {:invalid_cache_key, {:invalid_key_list, other}}}

  defp validate_revisit_key(revisit_key) do
    case Key.parse(revisit_key) do
      {:ok, %{key_type: :revisit}} ->
        :ok

      {:ok, _parsed} ->
        {:error, {:invalid_cache_key, {:expected_revisit_key, revisit_key}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_ttl_ms(opts) do
    case Keyword.get(opts, :ttl_ms) do
      value when is_integer(value) and value > 0 -> value
      _ -> Policy.revisit_ttl_ms()
    end
  end

  defp resolve_max_entries(opts) do
    case Keyword.get(opts, :max_entries) do
      value when is_integer(value) and value > 0 -> value
      _ -> Policy.revisit_max_entries()
    end
  end

  defp resolve_write_sweep_interval(opts) do
    case Keyword.get(opts, :write_sweep_interval) do
      value when is_integer(value) and value > 0 -> value
      _ -> Policy.revisit_write_sweep_interval()
    end
  end

  defp expired?(_written_at_ms, ttl_ms, _now_ms) when ttl_ms <= 0, do: true
  defp expired?(written_at_ms, ttl_ms, now_ms), do: now_ms - written_at_ms > ttl_ms

  defp now_ms(state) do
    case state.clock.() do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  end

  defp maybe_prune_expired_entries(entries, _ttl_ms, _now_ms, write_count, sweep_interval)
       when rem(write_count, sweep_interval) != 0 do
    {entries, 0}
  end

  defp maybe_prune_expired_entries(entries, ttl_ms, now_ms, _write_count, _sweep_interval) do
    Enum.reduce(entries, {%{}, 0}, fn {revisit_key, entry}, {kept_entries, pruned_count} ->
      if expired?(entry.written_at_ms, ttl_ms, now_ms) do
        {kept_entries, pruned_count + 1}
      else
        {Map.put(kept_entries, revisit_key, entry), pruned_count}
      end
    end)
  end

  defp enforce_entry_cap(entries, max_entries) do
    entry_count = map_size(entries)

    if entry_count <= max_entries do
      {entries, 0}
    else
      overflow = entry_count - max_entries

      evicted_keys =
        entries
        |> Enum.sort_by(fn {revisit_key, entry} ->
          {Map.get(entry, :last_accessed_at_ms, entry.written_at_ms), revisit_key}
        end)
        |> Enum.take(overflow)
        |> Enum.map(&elem(&1, 0))

      {Map.drop(entries, evicted_keys), length(evicted_keys)}
    end
  end

  defp container_type_from_revisit_key(revisit_key) do
    case Key.parse(revisit_key) do
      {:ok, %{container_type: container_type}} when container_type in [:course, :container] ->
        container_type

      _ ->
        :unknown
    end
  end

  defp error_class({reason, _detail}) when is_atom(reason), do: reason
  defp error_class({reason, _detail, _extra}) when is_atom(reason), do: reason
  defp error_class(reason) when is_atom(reason), do: reason
  defp error_class(_reason), do: :unknown
end
