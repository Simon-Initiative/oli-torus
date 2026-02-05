defmodule Oli.Analytics.Backfill.Notifier do
  @moduledoc """
  Broadcasts ClickHouse backfill updates to interested subscribers.
  """

  alias Phoenix.PubSub

  @topic "clickhouse_backfill:updates"

  @spec topic() :: String.t()
  def topic, do: @topic

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    PubSub.subscribe(Oli.PubSub, @topic)
  end

  @spec broadcast(atom(), map()) :: :ok
  def broadcast(source, metadata \\ %{}) do
    message = {:clickhouse_backfill_updated, %{source: source, metadata: metadata}}

    PubSub.broadcast(Oli.PubSub, @topic, message)
  end
end
