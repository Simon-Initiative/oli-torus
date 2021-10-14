defmodule Oli.Delivery.Updates.Subscriber do
  alias Phoenix.PubSub
  import Oli.Delivery.Updates.Messages

  ### Subscription API
  def subscribe_to_update_progress(section_id) do
    PubSub.subscribe(Oli.PubSub, message_update_progress(section_id))
  end

  ### Unsubscription API
  def unsubscribe_to_update_progress(section_id) do
    PubSub.unsubscribe(Oli.PubSub, message_update_progress(section_id))
  end
end
