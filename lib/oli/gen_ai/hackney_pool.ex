defmodule Oli.GenAI.HackneyPool do
  @moduledoc """
  Manages a dedicated hackney connection pool for GenAI/DOT HTTP requests.

  ## Configuration

  The pool size can be configured via the `GENAI_HACKNEY_POOL_SIZE` environment
  variable.

  ## Usage

  The pool is automatically started by the application supervisor. To use it
  with HTTPoison requests, add the pool option to hackney options:

      HTTPoison.post(url, body, headers, hackney: [pool: :genai_pool])

  """

  use GenServer
  require Logger

  @pool_name :genai_pool
  @default_pool_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the pool name to use for GenAI HTTP requests.
  """
  @spec pool_name() :: atom()
  def pool_name, do: @pool_name

  @doc """
  Returns the configured pool size.
  """
  @spec pool_size() :: pos_integer()
  def pool_size do
    Application.get_env(:oli, :genai_hackney_pool_size, @default_pool_size)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    size = pool_size()

    Logger.info("Starting GenAI hackney pool '#{@pool_name}' with max_connections: #{size}")

    case :hackney_pool.start_pool(@pool_name, max_connections: size) do
      :ok ->
        {:ok, %{pool_name: @pool_name, pool_size: size}}

      {:error, {:already_started, _pid}} ->
        Logger.debug("GenAI hackney pool '#{@pool_name}' already started")
        {:ok, %{pool_name: @pool_name, pool_size: size}}

      {:error, reason} ->
        Logger.error("Failed to start GenAI hackney pool: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %{pool_name: pool_name}) do
    Logger.info("Stopping GenAI hackney pool '#{pool_name}'")
    :hackney_pool.stop_pool(pool_name)
    :ok
  end
end
