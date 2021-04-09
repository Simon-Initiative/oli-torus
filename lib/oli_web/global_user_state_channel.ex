defmodule OliWeb.GlobalUserStateChannel do
  use Phoenix.Channel

  alias Oli.Delivery.ExtrinsicState
  alias Phoenix.PubSub

  def join("global:" <> user_id, _, socket) do
    send(self(), {:after_join, user_id})
    {:ok, socket}
  end

  def join(_, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:delta, msg}, socket) do
    push(socket, "delta", msg)
    {:noreply, socket}
  end

  def handle_info({:after_join, user_id}, socket) do
    # Do an initial full read and push to the socket
    {:ok, state} = ExtrinsicState.read_global(user_id)
    push(socket, "state", state)

    # But after that, only send delta based updates
    PubSub.subscribe(Oli.PubSub, "global:" <> user_id)

    {:noreply, socket}
  end
end
