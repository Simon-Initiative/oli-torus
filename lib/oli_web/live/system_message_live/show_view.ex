defmodule OliWeb.SystemMessageLive.ShowView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use Phoenix.HTML

  alias Oli.Notifications
  alias Oli.Notifications.PubSub

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

    {:ok, assign(socket, messages: messages), layout: false}
  end

  attr(:messages, :list, default: [])

  def render(assigns) do
    ~H"""
    <div
      :for={active_message <- @messages}
      class="system-banner alert alert-warning flex justify-between"
      role="alert"
    >
      <%= active_message.message |> Oli.Utils.find_and_linkify_urls_in_string() |> raw() %>
      <button
        id={"system-message-close-#{active_message.id}"}
        type="button"
        class="close"
        data-bs-dismiss="alert"
        aria-label="Close"
        phx-hook="SystemMessage"
        message-id={active_message.id}
      >
        <i class="fa-solid fa-xmark fa-lg"></i>
      </button>
    </div>
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
