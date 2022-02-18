defmodule Oli.Notifications.Worker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      period: :infinity,
      fields: [:args],
      keys: [:id, :display],
      states: [:available, :scheduled, :executing]
    ]

  alias Oli.Notifications.PubSub

  @moduledoc """
  An Oban worker that broadcasts a message for scheduled system messages. It receives a map representing the system
  message, and a boolean that defines whether it will be displayed or hidden.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"system_message" => system_message, "display" => true}
      }) do
    system_message
    |> Oli.Utils.atomize_keys()
    |> PubSub.display_system_message()

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"system_message" => system_message, "display" => false}
      }) do
    system_message
    |> Oli.Utils.atomize_keys()
    |> PubSub.hide_system_message()

    :ok
  end
end
