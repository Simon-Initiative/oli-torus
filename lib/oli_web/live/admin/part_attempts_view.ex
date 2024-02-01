defmodule OliWeb.Admin.PartAttemptsView do

  use OliWeb, :live_view

  alias Oli.Delivery.Attempts.PartAttemptCleaner

  def mount(_, _, socket) do

    status = PartAttemptCleaner.status()

    {:ok,
     assign(socket,
       title: "Part Attempts Cleaning",
       active: :cleaning,
       status: status,
       messages: []
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="grid grid-cols-12 mb-5">
        <div class="col-span-12">
          <h2 class="mb-5">
            Part Attempts Cleaning
          </h2>
          <p>
            <.button phx-click="start">
              Start
            </.button>
            <.button phx-click="stop">
              Stop
            </.button>
          </p>
          <p>
            <strong>Status:</strong> <%= @status %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp add_message(message, socket) do

    messages = [message | socket.assigns.messages]
    |> Enum.take(10)

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_event("start", _, socket) do
    PartAttemptCleaner.start()
    {:noreply, assign(socket, status: PartAttemptCleaner.status())}
  end

  def handle_event("stop", _, socket) do
    PartAttemptCleaner.stop()
    {:noreply, assign(socket, status: PartAttemptCleaner.status())}
  end

  def handle_info({:seed_complete}, socket) do
    add_message("Seed complete", socket)
  end

end
