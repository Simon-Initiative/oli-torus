defmodule OliWeb.LiveSessionPlugs.SetSystemMessages do
  @moduledoc """
  This live session plug sets the hooks needed to recieve and render system messages.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Oli.Notifications
  alias Oli.Notifications.PubSub

  def on_mount(:default, _params, session, socket) do
    if connected?(socket) do
      PubSub.subscribe_to_system_messages()
      dismissed_messages = session["dismissed_messages"] || []

      messages =
        Notifications.list_active_system_messages()
        |> filter_dismissed_messages(dismissed_messages)

      socket =
        socket
        |> assign(system_messages: messages)
        |> attach_hook(:system_messages_hook, :handle_info, fn
          {:display_message, %{id: id} = system_message}, socket ->
            messages =
              delete_system_message(id, socket.assigns.system_messages)

            {:cont, assign(socket, system_messages: [system_message | messages])}

          {:hide_message, %{id: id}}, socket ->
            messages = delete_system_message(id, socket.assigns.system_messages)

            {:cont, assign(socket, system_messages: messages)}

          _other_message, socket ->
            {:cont, socket}
        end)

      {:cont, socket}
    else
      {:cont, assign(socket, system_messages: [])}
    end
  end

  defp delete_system_message(id, messages) do
    Enum.filter(messages, &(&1.id != id))
  end

  defp filter_dismissed_messages(messages, dismissed_messages) do
    Enum.filter(messages, &(&1.id not in dismissed_messages))
  end
end
