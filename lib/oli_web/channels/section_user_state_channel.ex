defmodule OliWeb.SectionUserStateChannel do
  use Phoenix.Channel

  alias Oli.Delivery.ExtrinsicState
  alias Phoenix.PubSub

  def join("user_section_state:" <> section_user, _, socket) do
    case String.split(section_user, ":") do
      [section_slug, user_id] ->
        send(self(), {:after_join, {section_slug, Integer.parse(user_id)}})
        {:ok, socket}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join(_, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:delta, msg}, socket) do
    push(socket, "delta", msg)
    {:noreply, socket}
  end

  def handle_info({:deletion, msg}, socket) do
    push(socket, "deletion", msg)
    {:noreply, socket}
  end

  def handle_info({:after_join, {section_slug, user_id}}, socket) do
    # Do an initial full read and push to the socket
    {:ok, state} = ExtrinsicState.read_section(user_id, section_slug)
    push(socket, "state", state)

    # But after that, only send delta based updates
    PubSub.subscribe(Oli.PubSub, "user_section_state:" <> section_slug <> ":" <> user_id)

    {:noreply, socket}
  end
end
