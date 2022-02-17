defmodule Oli.Groups.PubSubTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Notifications.PubSub

  test "broadcasts an event to display a system message" do
    PubSub.subscribe_to_system_messages()
    message = params_for(:system_message)
    PubSub.display_system_message(message)
    assert_receive {:display_message, ^message}
  end

  test "broadcasts an event to hide a system message" do
    PubSub.subscribe_to_system_messages()
    message = params_for(:system_message)
    PubSub.hide_system_message(message)
    assert_receive {:hide_message, ^message}
  end
end
