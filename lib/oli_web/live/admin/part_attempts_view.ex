defmodule OliWeb.Admin.PartAttemptsView do
  use OliWeb, :live_view

  alias Oli.Delivery.Attempts.PartAttemptCleaner
  alias Phoenix.PubSub

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    status = PartAttemptCleaner.status()

    PubSub.subscribe(Oli.PubSub, "part_attempt_cleaner")

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
    <div>
      <div class="mt-5 p-3 bg-gray-900 text-gray-300 h-96 relative">
        <code class="h-96">
          <div class="mb-4 flex justify-between">
            <%= if @status.running do %>
              <div class="text-blue-500">Running</div>
            <% else %>
              <div class="text-yellow-500">Stopped</div>
            <% end %>
            <div class="text-green-500">
              <span class="mr-5">Batches: {@status.batches_complete}</span>
              <span class="mr-5">Records Visited: {@status.records_visited}</span>
              <span>Records Deleted: {@status.records_deleted}</span>
            </div>
          </div>

          <%= for message <- @messages do %>
            <div>{message}</div>
          <% end %>

          <div class="absolute bottom-3 left-3">
            <button
              class="border-solid border-2 border-gray-400 hover:bg-gray-400 text-gray-300 hover:text-gray-800 font-bold py-1 px-2"
              phx-click="stop"
            >
              Stop
            </button>
            <button
              class="border-solid border-2 border-gray-400 hover:bg-gray-400 text-gray-300 hover:text-gray-800 font-bold py-1 px-2"
              phx-click="start"
            >
              Start
            </button>
          </div>
          <div class="absolute bottom-3 right-3">
            <select
              id="wait"
              phx-hook="SelectListener"
              phx-change="set_wait_time"
              class="border-solid border-2 border-gray-400 hover:bg-gray-400 bg-gray-900 text-gray-300 hover:text-gray-800 font-bold py-1 px-2"
            >
              <option selected={@status.wait_time == 0} value="0">No wait in between batches</option>
              <option selected={@status.wait_time == 100} value="100">100 milliseconds</option>
              <option selected={@status.wait_time == 250} value="250">250 milliseconds</option>
              <option selected={@status.wait_time == 500} value="500">500 milliseconds</option>
              <option selected={@status.wait_time == 1000} value="1000">1 second</option>
            </select>
          </div>
        </code>
      </div>
    </div>
    """
  end

  defp add_message(message, state, socket) do
    # Format a timestamp from right now
    timestamp =
      DateTime.utc_now()
      |> Timex.format!("{ISO:Extended}")

    messages = Enum.take(socket.assigns.messages, -9)
    new_message = "#{timestamp}: #{message}"

    {:noreply, assign(socket, messages: messages ++ [new_message], status: state)}
  end

  def handle_event("start", _, socket) do
    {:noreply, assign(socket, status: PartAttemptCleaner.start())}
  end

  def handle_event("stop", _, socket) do
    {:noreply, assign(socket, status: PartAttemptCleaner.stop())}
  end

  def handle_event("set_wait_time", %{"value" => value}, socket) do
    int_value = String.to_integer(value)
    {:noreply, assign(socket, status: PartAttemptCleaner.set_wait_time(int_value))}
  end

  def handle_info({:batch_finished, state, details}, socket) do
    "[#{details.id}] #{details.records_deleted} deleted out of #{details.records_visited} visited"
    |> add_message(state, socket)
  end

  def handle_info({:no_more_attempts, state}, socket) do
    add_message("No more attempts to clean", state, socket)
  end
end
