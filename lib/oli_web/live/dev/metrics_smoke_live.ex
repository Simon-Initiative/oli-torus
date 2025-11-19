defmodule OliWeb.Dev.MetricsSmokeLive do
  use OliWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       feature: "demo",
       duration_ms: 42,
       last_result: nil,
       busy?: false
     )}
  end

  @impl true
  def handle_event("set", %{"feature" => feature, "duration_ms" => duration_ms}, socket) do
    duration_ms = parse_int(duration_ms, socket.assigns.duration_ms)
    {:noreply, assign(socket, feature: feature, duration_ms: duration_ms)}
  end

  def handle_event("inc", _params, socket) do
    tags = %{"feature" => socket.assigns.feature, "stage" => "smoke", "action" => "inc"}

    result = Appsignal.increment_counter("torus.feature.exec", 1, tags)
    {:noreply, assign(socket, last_result: {:inc, result})}
  end

  def handle_event("dist", _params, socket) do
    tags = %{"feature" => socket.assigns.feature, "stage" => "smoke", "action" => "dist"}

    result =
      Appsignal.add_distribution_value(
        "torus.feature.duration_ms",
        socket.assigns.duration_ms,
        tags
      )

    {:noreply, assign(socket, last_result: {:dist, result})}
  end

  defp parse_int("", default), do: default

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} -> int
      :error -> default
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container p-4">
      <h2 class="text-xl font-semibold mb-4">AppSignal Metrics Smoke Test (dev only)</h2>

      <form phx-change="set" class="space-y-3">
        <.input type="text" name="feature" label="Feature" value={@feature} />
        <.input type="number" name="duration_ms" label="Duration (ms)" value={@duration_ms} />
      </form>

      <div class="flex gap-2 mt-4">
        <.button phx-click="inc">Increment Counter</.button>
        <.button phx-click="dist">Add Distribution Value</.button>
      </div>

      <div class="mt-6 text-sm text-gray-600">
        <p>Metric keys:</p>
        <ul class="list-disc ml-6">
          <li><code>torus.feature.exec</code> (counter)</li>
          <li><code>torus.feature.duration_ms</code> (distribution)</li>
        </ul>
        <p class="mt-2">Tags sent:</p>
        <pre class="bg-gray-50 p-2 rounded">
          <code>&lbrace;"feature" =&gt; "<%= @feature %>", "stage" =&gt; "smoke", "action" =&gt; "inc|dist"&rbrace;</code>
        </pre>
        <%= if @last_result do %>
          <p class="mt-2">Last call result: {inspect(@last_result)}</p>
        <% end %>
      </div>
    </div>
    """
  end
end
