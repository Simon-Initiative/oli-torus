defmodule Oli.GenAI.HackneyPool do
  @moduledoc """
  Manages dedicated hackney connection pools for GenAI HTTP requests.

  Pools are split by latency class:
  - `:genai_fast_pool` for fast models
  - `:genai_slow_pool` for slow models

  ## Configuration

  Pool sizes can be configured via:
  - `GENAI_FAST_POOL_SIZE`
  - `GENAI_SLOW_POOL_SIZE`

  ## Usage

  The pools are automatically started by the application supervisor. To use a
  pool with HTTPoison requests, add the pool option to hackney options:

      HTTPoison.post(url, body, headers, hackney: [pool: :genai_fast_pool])

  """

  use GenServer
  require Logger

  alias Oli.GenAI.Completions.RegisteredModel

  @fast_pool_name :genai_fast_pool
  @slow_pool_name :genai_slow_pool
  @default_pool_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the default pool name to use for GenAI HTTP requests.
  """
  @spec pool_name() :: atom()
  def pool_name, do: @slow_pool_name

  @doc """
  Returns the pool name for a given pool class or RegisteredModel.
  """
  @spec pool_name(:fast | :slow | RegisteredModel.t()) :: atom()
  def pool_name(:fast), do: @fast_pool_name
  def pool_name(:slow), do: @slow_pool_name
  def pool_name(%RegisteredModel{pool_class: pool_class}), do: pool_name(pool_class)
  def pool_name(_), do: @slow_pool_name

  @doc """
  Returns the configured pool size for the slow pool (default).
  """
  @spec pool_size() :: pos_integer()
  def pool_size, do: pool_size(:slow)

  @doc """
  Returns the configured pool size for the given pool class.
  """
  @spec pool_size(:fast | :slow) :: pos_integer()
  def pool_size(:fast) do
    Application.get_env(:oli, :genai_hackney_fast_pool_size, @default_pool_size)
  end

  def pool_size(:slow) do
    Application.get_env(:oli, :genai_hackney_slow_pool_size, @default_pool_size)
  end

  @doc """
  Returns the current max connections for the given pool class.
  Falls back to configured pool size if the pool isn't available.
  """
  @spec max_connections(:fast | :slow) :: pos_integer()
  def max_connections(pool_class) do
    pool_name = pool_name(pool_class)

    try do
      case :hackney_pool.max_connections(pool_name) do
        size when is_integer(size) -> size
        _ -> pool_size(pool_class)
      end
    catch
      :exit, _ -> pool_size(pool_class)
    end
  end

  @doc """
  Sets the max connections for the given pool class at runtime.
  """
  @spec set_max_connections(:fast | :slow, pos_integer()) :: :ok
  def set_max_connections(pool_class, size) when is_integer(size) and size > 0 do
    pool_name = pool_name(pool_class)
    :hackney_pool.set_max_connections(pool_name, size)
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    fast_size = pool_size(:fast)
    slow_size = pool_size(:slow)

    Logger.info(
      "Starting GenAI hackney pool '#{@fast_pool_name}' with max_connections: #{fast_size}"
    )

    Logger.info(
      "Starting GenAI hackney pool '#{@slow_pool_name}' with max_connections: #{slow_size}"
    )

    with :ok <- start_pool(@fast_pool_name, fast_size),
         :ok <- start_pool(@slow_pool_name, slow_size) do
      {:ok, %{fast_pool_size: fast_size, slow_pool_size: slow_size}}
    else
      {:error, reason} ->
        Logger.error("Failed to start GenAI hackney pools: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Stopping GenAI hackney pool '#{@fast_pool_name}'")
    :hackney_pool.stop_pool(@fast_pool_name)

    Logger.info("Stopping GenAI hackney pool '#{@slow_pool_name}'")
    :hackney_pool.stop_pool(@slow_pool_name)
    :ok
  end

  defp start_pool(pool_name, size) do
    case :hackney_pool.start_pool(pool_name, max_connections: size) do
      :ok ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("GenAI hackney pool '#{pool_name}' already started")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
