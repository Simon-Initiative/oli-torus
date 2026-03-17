defmodule Oli.Dashboard.Cache.InProcessStore do
  @moduledoc """
  Session-local in-process cache store for dashboard oracle payloads.
  """

  use GenServer

  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.Policy
  alias Oli.Dashboard.Scope

  @type container_key :: {pos_integer(), Scope.container_type(), pos_integer() | nil}

  @type entry :: %{
          payload: map(),
          written_at_ms: non_neg_integer(),
          container_key: container_key()
        }

  @type state :: %{
          entries: %{optional(Key.cache_key()) => entry()},
          container_access: %{optional(container_key()) => non_neg_integer()},
          enrollment_count: non_neg_integer(),
          clock: (-> integer())
        }

  @type error :: {:invalid_cache_key, term()} | {:invalid_context_id, term()}

  @doc "Starts a session-local in-process cache store."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {start_opts, genserver_opts} = Keyword.split(opts, [:clock, :enrollment_count])
    GenServer.start_link(__MODULE__, start_opts, genserver_opts)
  end

  @doc "Returns required-key hits and misses for a deterministic key list."
  @spec lookup_required(GenServer.server(), [Key.cache_key()], keyword()) ::
          {:ok, %{hits: map(), misses: [Key.cache_key()], expired: [Key.cache_key()]}}
  def lookup_required(store, cache_keys, opts \\ []) do
    GenServer.call(store, {:lookup_required, cache_keys, opts})
  end

  @doc "Writes a single oracle payload entry."
  @spec write_oracle(GenServer.server(), Key.cache_key(), map(), keyword()) ::
          {:ok, %{evicted_containers: non_neg_integer()}} | {:error, error()}
  def write_oracle(store, cache_key, payload, opts \\ []) do
    GenServer.call(store, {:write_oracle, cache_key, payload, opts})
  end

  @doc "Touches container recency for LRU bookkeeping."
  @spec touch_container(
          GenServer.server(),
          pos_integer(),
          Scope.container_type(),
          pos_integer() | nil,
          keyword()
        ) :: {:ok, %{evicted_containers: non_neg_integer()}} | {:error, error()}
  def touch_container(store, context_id, container_type, container_id, opts \\ []) do
    GenServer.call(store, {:touch_container, context_id, container_type, container_id, opts})
  end

  @doc "Returns store state snapshot for tests/diagnostics."
  @spec snapshot(GenServer.server()) :: {:ok, state()}
  def snapshot(store) do
    GenServer.call(store, :snapshot)
  end

  @impl true
  def init(opts) do
    clock =
      case Keyword.get(opts, :clock) do
        clock when is_function(clock, 0) -> clock
        _ -> fn -> System.monotonic_time(:millisecond) end
      end

    enrollment_count = normalize_enrollment_count(Keyword.get(opts, :enrollment_count, 0))

    {:ok,
     %{
       entries: %{},
       container_access: %{},
       enrollment_count: enrollment_count,
       clock: clock
     }}
  end

  @impl true
  def handle_call({:lookup_required, cache_keys, opts}, _from, state) do
    now_ms = now_ms(state)
    ttl_ms = resolve_ttl_ms(opts)

    {hits, misses, expired, entries, container_access} =
      Enum.reduce(
        cache_keys,
        {%{}, [], [], state.entries, state.container_access},
        fn cache_key, {hits_acc, misses_acc, expired_acc, entries_acc, container_access_acc} ->
          case Map.get(entries_acc, cache_key) do
            nil ->
              {hits_acc, [cache_key | misses_acc], expired_acc, entries_acc, container_access_acc}

            %{written_at_ms: written_at_ms, payload: payload, container_key: container_key} ->
              if expired?(written_at_ms, ttl_ms, now_ms) do
                {
                  hits_acc,
                  [cache_key | misses_acc],
                  [cache_key | expired_acc],
                  Map.delete(entries_acc, cache_key),
                  container_access_acc
                }
              else
                {
                  Map.put(hits_acc, cache_key, payload),
                  misses_acc,
                  expired_acc,
                  entries_acc,
                  Map.put(container_access_acc, container_key, now_ms)
                }
              end
          end
        end
      )

    container_access = prune_container_access(entries, container_access)

    next_state = %{state | entries: entries, container_access: container_access}
    result = %{hits: hits, misses: Enum.reverse(misses), expired: Enum.reverse(expired)}

    {:reply, {:ok, result}, next_state}
  end

  def handle_call({:write_oracle, cache_key, payload, opts}, _from, state) when is_map(payload) do
    with {:ok, container_key} <- container_key_from_cache_key(cache_key) do
      now_ms = now_ms(state)

      entries =
        Map.put(state.entries, cache_key, %{
          payload: payload,
          written_at_ms: now_ms,
          container_key: container_key
        })

      container_access = Map.put(state.container_access, container_key, now_ms)
      container_cap = resolve_container_cap(opts, state.enrollment_count)

      {entries, container_access, evicted_containers} =
        evict_excess_containers(entries, container_access, container_cap)

      next_state = %{state | entries: entries, container_access: container_access}

      {:reply, {:ok, %{evicted_containers: evicted_containers}}, next_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:write_oracle, _cache_key, payload, _opts}, _from, state) do
    {:reply, {:error, {:invalid_payload, payload}}, state}
  end

  def handle_call(
        {:touch_container, context_id, container_type, container_id, opts},
        _from,
        state
      ) do
    with {:ok, normalized_context_id} <- normalize_context_id(context_id),
         {:ok, normalized_container_id} <- normalize_container(container_type, container_id) do
      container_key = {normalized_context_id, container_type, normalized_container_id}

      if Map.has_key?(state.container_access, container_key) do
        touched_container_access =
          Map.put(state.container_access, container_key, now_ms(state))

        container_cap = resolve_container_cap(opts, state.enrollment_count)

        {entries, container_access, evicted_containers} =
          evict_excess_containers(state.entries, touched_container_access, container_cap)

        next_state = %{state | entries: entries, container_access: container_access}

        {:reply, {:ok, %{evicted_containers: evicted_containers}}, next_state}
      else
        {:reply, {:ok, %{evicted_containers: 0}}, state}
      end
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, state}, state}
  end

  defp container_key_from_cache_key(cache_key) do
    case Key.parse(cache_key) do
      {:ok,
       %{
         dashboard_context_id: dashboard_context_id,
         container_type: container_type,
         container_id: container_id
       }} ->
        {:ok, {dashboard_context_id, container_type, container_id}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_context_id(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp normalize_context_id(value), do: {:error, {:invalid_context_id, value}}

  defp normalize_container(:course, nil), do: {:ok, nil}

  defp normalize_container(:container, container_id)
       when is_integer(container_id) and container_id > 0, do: {:ok, container_id}

  defp normalize_container(container_type, container_id),
    do: {:error, {:invalid_container, container_type, container_id}}

  defp now_ms(state) do
    case state.clock.() do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  end

  defp expired?(_written_at_ms, ttl_ms, _now_ms) when ttl_ms <= 0, do: true
  defp expired?(written_at_ms, ttl_ms, now_ms), do: now_ms - written_at_ms > ttl_ms

  defp resolve_ttl_ms(opts) do
    case Keyword.get(opts, :ttl_ms) do
      value when is_integer(value) and value > 0 -> value
      _ -> Policy.inprocess_ttl_ms()
    end
  end

  defp resolve_container_cap(opts, default_enrollment_count) do
    case Keyword.get(opts, :container_cap) do
      value when is_integer(value) and value > 0 ->
        value

      _ ->
        enrollment_count =
          opts
          |> Keyword.get(:enrollment_count, default_enrollment_count)
          |> normalize_enrollment_count()

        Policy.container_cap_for_enrollment(enrollment_count)
    end
  end

  defp normalize_enrollment_count(value) when is_integer(value) and value >= 0, do: value
  defp normalize_enrollment_count(_), do: 0

  defp evict_excess_containers(entries, container_access, container_cap) do
    container_count = map_size(container_access)

    if container_count <= container_cap do
      {entries, container_access, 0}
    else
      overflow = container_count - container_cap

      evicted_container_keys =
        container_access
        |> Enum.sort_by(fn {container_key, last_access_ms} -> {last_access_ms, container_key} end)
        |> Enum.take(overflow)
        |> Enum.map(&elem(&1, 0))

      evicted_set = MapSet.new(evicted_container_keys)

      kept_entries =
        Enum.reduce(entries, %{}, fn {cache_key, entry}, acc ->
          if MapSet.member?(evicted_set, entry.container_key) do
            acc
          else
            Map.put(acc, cache_key, entry)
          end
        end)

      kept_container_access = Map.drop(container_access, evicted_container_keys)

      {kept_entries, kept_container_access, length(evicted_container_keys)}
    end
  end

  defp prune_container_access(entries, container_access) do
    active_container_keys =
      entries
      |> Map.values()
      |> Enum.map(& &1.container_key)
      |> MapSet.new()

    Enum.reduce(container_access, %{}, fn {container_key, touched_at_ms}, acc ->
      if MapSet.member?(active_container_keys, container_key) do
        Map.put(acc, container_key, touched_at_ms)
      else
        acc
      end
    end)
  end
end
