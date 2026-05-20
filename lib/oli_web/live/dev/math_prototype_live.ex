defmodule OliWeb.Dev.MathPrototypeLive do
  use OliWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       expression: "1 + 2",
       server_result: nil,
       client_result: nil
     )}
  end

  @impl true
  def handle_event("set_expression", %{"expression" => expression}, socket) do
    {:noreply, assign(socket, expression: expression)}
  end

  def handle_event("parse_server", _params, socket) do
    {:noreply, assign(socket, server_result: format_server_result(socket.assigns.expression))}
  end

  def handle_event("client_parse_result", result, socket) do
    {:noreply, assign(socket, client_result: result)}
  end

  defp format_server_result(expression) do
    case Oli.Math.parse(expression) do
      {:ok, %{debug: debug} = value} ->
        %{status: "ok", value: debug, inspect: inspect(value)}

      {:error, %{debug: debug} = value} ->
        %{status: "error", value: debug, inspect: inspect(value)}

      other ->
        %{status: "unknown", value: inspect(other), inspect: inspect(other)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container p-4">
      <h1 class="text-2xl font-semibold mb-2">Math Prototype</h1>
      <p class="text-sm text-gray-600 mb-6">
        Dev-only playground for comparing server and browser Gleam math parser output.
      </p>

      <div id="math-prototype" phx-hook="MathPrototype" class="space-y-6">
        <form phx-change="set_expression" class="max-w-3xl">
          <.input
            id="math-expression"
            type="text"
            name="expression"
            label="Math expression"
            value={@expression}
          />
        </form>

        <div class="flex flex-wrap gap-2">
          <.button phx-click="parse_server">Parse on server</.button>
          <.button type="button" id="parse-client">Parse in browser</.button>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="border rounded p-4">
            <h2 class="text-lg font-semibold mb-3">Server result</h2>
            <.result_panel result={@server_result} />
          </div>

          <div class="border rounded p-4">
            <h2 class="text-lg font-semibold mb-3">Browser result</h2>
            <.result_panel result={@client_result} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :result, :any, required: true

  defp result_panel(assigns) do
    assigns =
      assign(assigns,
        status: result_value(assigns.result, :status),
        value: result_value(assigns.result, :value),
        inspect: result_value(assigns.result, :inspect)
      )

    ~H"""
    <%= if @result do %>
      <div class="space-y-2 text-sm">
        <div>
          <span class="font-semibold">Status:</span>
          <span>{@status}</span>
        </div>
        <div>
          <span class="font-semibold">Value:</span>
          <code class="bg-gray-50 p-1 rounded">{@value}</code>
        </div>
        <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@inspect}</code></pre>
      </div>
    <% else %>
      <p class="text-sm text-gray-500">No parse has been run yet.</p>
    <% end %>
    """
  end

  defp result_value(nil, _key), do: nil
  defp result_value(result, key), do: Map.get(result, key) || Map.get(result, Atom.to_string(key))
end
