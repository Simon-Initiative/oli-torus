defmodule Oli.Notifications.PubSub do
  @moduledoc """

  This module encapsulates all broadcasting functionality for system notifications.

  """

  alias Phoenix.PubSub
  require Logger

  @topic "event:system_message"

  @doc """
  Subscribes to changes on system messages.
  """
  def subscribe_to_system_messages() do
    PubSub.subscribe(Oli.PubSub, @topic)

    Logger.info("Subscribing to system messages for topic #{@topic}")
  end

  @doc """
  Broadcasts that a system message was updated to be displayed.
  """
  def display_system_message(message), do: broadcast_system_message(:display_message, message)

  @doc """
  Broadcasts that a system message was updated to be hidden.
  """
  def hide_system_message(message), do: broadcast_system_message(:hide_message, message)

  defp broadcast_system_message(type, message_state) do
    PubSub.broadcast(
      Oli.PubSub,
      @topic,
      {type, message_state}
    )

    Logger.info("Broadcasting message of type #{type} for topic #{@topic}")
  end
end
