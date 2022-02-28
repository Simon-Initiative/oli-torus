defmodule OliWeb.SystemMessageLive.ShowView do
  use Surface.LiveView

  alias Oli.Notifications
  alias Oli.Notifications.PubSub

  data messages, :list, default: []

  def mount(
        _params,
        session,
        socket
      ) do
    PubSub.subscribe_to_system_messages()
    dismissed_messages = session["dismissed_messages"] || []

    messages =
      Notifications.list_active_system_messages()
      |> filter_dismissed_messages(dismissed_messages)

    {:ok, assign(socket, messages: messages)}
  end

  def render(assigns) do
    ~F"""
    {#for active_message <- @messages}
      <div class="system-banner alert alert-warning" role="alert">

        {active_message.message |> Oli.Utils.find_and_linkify_urls_in_string() |> raw()}

        <button id={"system-message-close-#{active_message.id}"} type="button" class="close" data-dismiss="alert" aria-label="Close" phx-hook="SystemMessage" message-id={active_message.id}>
          <span aria-hidden="true">&times;</span>
        </button>

      </div>
    {/for}
    """
  end

  def handle_info({:display_message, %{id: id} = system_message}, socket) do
    messages = delete_system_message(id, socket.assigns.messages)

    {:noreply, assign(socket, messages: [system_message | messages])}
  end

  def handle_info({:hide_message, %{id: id}}, socket) do
    messages = delete_system_message(id, socket.assigns.messages)

    {:noreply, assign(socket, messages: messages)}
  end

  defp delete_system_message(id, messages) do
    Enum.filter(messages, &(&1.id != id))
  end

  defp filter_dismissed_messages(messages, dismissed_messages) do
    Enum.filter(messages, &(&1.id not in dismissed_messages))
  end
end
