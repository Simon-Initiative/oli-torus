defmodule Oli.ScopedFeatureFlags.CacheSubscriber do
  @moduledoc false

  use GenServer

  @topic "feature_rollouts"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    Phoenix.PubSub.subscribe(Oli.PubSub, @topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info(message, state) do
    Oli.ScopedFeatureFlags.handle_pubsub_message(message)
    {:noreply, state}
  end
end
