defmodule OliWeb.SystemMessageLive.ShowView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Notifications
  alias Oli.Notifications.PubSub

  data messages, :list, default: []

  def mount(
        _params,
        _session,
        socket
      ) do
    PubSub.subscribe_to_system_messages()
    messages = Notifications.list_active_system_messages()

    {:ok, assign(socket, messages: messages)}
  end

  def render(assigns) do
    ~F"""
    {#for active_message <- @messages}
      <div class="system-banner alert alert-warning" role="alert">

        {active_message.message}

        <button type="button" class="close" data-dismiss="alert" aria-label="Close" phx-click="dismiss_message" phx-value-key="info">
          <span style="color: black"aria-hidden="true">&times;</span>
        </button>

      </div>
    {/for}
    """
  end

  def handle_event("dismiss_message", _params, socket) do
    {:noreply, socket}
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
    Enum.filter(messages, fn m -> m.id != id end)
  end
end
