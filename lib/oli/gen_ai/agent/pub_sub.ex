defmodule Oli.GenAI.Agent.PubSub do
  @moduledoc "PubSub topics & broadcasts for LiveView."
  require Logger

  @spec topic(String.t()) :: String.t()
  def topic(run_id), do: "agent:run:" <> run_id

  @spec broadcast_step(String.t(), map) :: :ok
  def broadcast_step(run_id, step) do
    topic = topic(run_id)
    message = {:agent_step, step}

    case Application.get_env(:oli, OliWeb.Endpoint)[:pubsub_server] do
      nil ->
        Logger.debug("Mock: Broadcasting step to #{topic}: #{inspect(step)}")

      pubsub_server ->
        Phoenix.PubSub.broadcast(pubsub_server, topic, message)
    end

    :ok
  end

  @spec broadcast_status(String.t(), map) :: :ok
  def broadcast_status(run_id, status) do
    topic = topic(run_id)
    message = {:agent_status, status}

    case Application.get_env(:oli, OliWeb.Endpoint)[:pubsub_server] do
      nil ->
        Logger.debug("Mock: Broadcasting status to #{topic}: #{inspect(status)}")

      pubsub_server ->
        Phoenix.PubSub.broadcast(pubsub_server, topic, message)
    end

    :ok
  end

  @spec broadcast_stats(String.t(), map) :: :ok
  def broadcast_stats(run_id, stats) do
    topic = topic(run_id)
    message = {:agent_stats, stats}

    case Application.get_env(:oli, OliWeb.Endpoint)[:pubsub_server] do
      nil ->
        Logger.debug("Mock: Broadcasting stats to #{topic}: #{inspect(stats)}")

      pubsub_server ->
        Phoenix.PubSub.broadcast(pubsub_server, topic, message)
    end

    :ok
  end

  @spec broadcast_draft(String.t(), map) :: :ok
  def broadcast_draft(run_id, draft) do
    topic = topic(run_id)
    message = {:agent_draft, draft}

    case Application.get_env(:oli, OliWeb.Endpoint)[:pubsub_server] do
      nil ->
        Logger.debug("Mock: Broadcasting draft to #{topic}: #{inspect(draft)}")

      pubsub_server ->
        Phoenix.PubSub.broadcast(pubsub_server, topic, message)
    end

    :ok
  end
end
