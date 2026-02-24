defmodule Oli.Dashboard.RevisitCache do
  @moduledoc """
  Node-local revisit cache store for explicit-container return flows.
  """

  use GenServer

  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.Policy

  @type entry :: %{
          payload: map(),
          written_at_ms: non_neg_integer()
        }

  @type state :: %{
          entries: %{optional(Key.revisit_key()) => entry()},
          clock: (-> integer())
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

    {:ok, %{entries: %{}, clock: clock}}
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
                {Map.put(hits_acc, revisit_key, payload), misses_acc, expired_acc, entries_acc}
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

  def handle_call({:write, revisit_key, payload, _opts}, _from, state) when is_map(payload) do
    with :ok <- validate_revisit_key(revisit_key) do
      now_ms = now_ms(state)

      entries =
        Map.put(state.entries, revisit_key, %{
          payload: payload,
          written_at_ms: now_ms
        })

      {:reply, :ok, %{state | entries: entries}}
    else
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:write, _revisit_key, payload, _opts}, _from, state) do
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

  defp expired?(_written_at_ms, ttl_ms, _now_ms) when ttl_ms <= 0, do: true
  defp expired?(written_at_ms, ttl_ms, now_ms), do: now_ms - written_at_ms > ttl_ms

  defp now_ms(state) do
    case state.clock.() do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  end
end
