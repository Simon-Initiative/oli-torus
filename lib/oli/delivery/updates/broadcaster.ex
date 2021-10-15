defmodule Oli.Delivery.Updates.Broadcaster do
  @moduledoc """
  This module encapsulates all broadcasting functionality for update events.
  """

  import Oli.Delivery.Updates.Messages
  alias Phoenix.PubSub

  ### Broadcast events

  @doc """
  Broadcasts an update's progress. Progress is expected to be an integer
  from 0-99 or :complete
  """
  def broadcast_update_progress(section_id, publication_id, progress) do
    PubSub.broadcast(
      Oli.PubSub,
      message_update_progress(section_id),
      {:update_progress, section_id, publication_id, progress}
    )
  end
end
