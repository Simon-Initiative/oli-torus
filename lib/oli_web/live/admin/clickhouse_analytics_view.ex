defmodule OliWeb.Admin.ClickHouseAnalyticsView do
  use OliWeb, :live_view

  alias Oli.Analytics.XAPI.ClickHouseSchema
  alias OliWeb.Common.Breadcrumb
  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    if Application.get_env(:oli, :env) == :dev do
      {:ok,
       assign(socket,
         title: "ClickHouse Analytics",
         breadcrumb: breadcrumb(),
         health_status: nil,
         query_result: nil,
         selected_query: "",
         custom_query: "",
         executing: false,
         sample_queries: ClickHouseSchema.sample_video_analytics_queries()
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "ClickHouse Analytics is only available in development mode")
       |> push_navigate(to: ~p"/admin")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="w-full bg-white dark:bg-gray-900 dark:text-white p-6">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-3xl font-bold mb-6">ClickHouse Analytics Dashboard</h1>
        <!-- Health Check Section -->
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold">ClickHouse Status</h2>
            <.button phx-click="health_check" class="btn-primary">
              Check Health
            </.button>
          </div>

          <%= if @health_status do %>
            <div class="mt-3">
              <%= case @health_status do %>
                <% {:ok, :healthy} -> %>
                  <div class="text-green-600 dark:text-green-400">
                    ✅ ClickHouse is healthy and responsive
                  </div>
                <% {:error, reason} -> %>
                  <div class="text-red-600 dark:text-red-400">
                    ❌ ClickHouse health check failed: <%= inspect(reason) %>
                  </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <!-- Sample Queries Section -->
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <h2 class="text-xl font-semibold mb-4">Sample Analytics Queries</h2>

          <div class="grid gap-4">
            <%= for {query_name, query} <- @sample_queries do %>
              <div class="border dark:border-gray-600 rounded-lg p-4">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="font-medium text-lg"><%= humanize_query_name(query_name) %></h3>
                  <.button
                    phx-click="run_sample_query"
                    phx-value-query={query_name}
                    class="btn-sm btn-secondary"
                    disabled={@executing}
                  >
                    <%= if @executing, do: "Running...", else: "Run Query" %>
                  </.button>
                </div>
                <pre class="text-xs bg-gray-100 dark:bg-gray-700 p-3 rounded overflow-x-auto"><%= String.trim(query) %></pre>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Custom Query Section -->
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <h2 class="text-xl font-semibold mb-4">Custom Query</h2>

          <.form for={%{}} as={:query} phx-submit="run_custom_query">
            <div class="mb-4">
              <textarea
                name="custom_query"
                rows="6"
                class="w-full p-3 border rounded-lg dark:bg-gray-700 dark:border-gray-600 font-mono text-sm"
                placeholder="Enter your ClickHouse SQL query here..."
                value={@custom_query}
              ></textarea>
            </div>

            <.button type="submit" class="btn-primary" disabled={@executing}>
              <%= if @executing, do: "Executing...", else: "Execute Query" %>
            </.button>
          </.form>
        </div>
        <!-- Results Section -->
        <%= if @query_result do %>
          <div class="bg-white dark:bg-gray-800 border dark:border-gray-600 rounded-lg p-4">
            <h2 class="text-xl font-semibold mb-4">Query Results</h2>

            <%= case @query_result do %>
              <% {:ok, result} -> %>
                <div class="text-green-600 dark:text-green-400 mb-2">
                  ✅ Query executed successfully
                </div>
                <%= if result.body != "" do %>
                  <pre class="bg-gray-100 dark:bg-gray-700 p-3 rounded overflow-x-auto text-sm"><%= result.body %></pre>
                <% else %>
                  <div class="text-gray-500 dark:text-gray-400 italic">
                    Query executed successfully (no output)
                  </div>
                <% end %>
              <% {:error, reason} -> %>
                <div class="text-red-600 dark:text-red-400 mb-2">❌ Query failed</div>
                <pre class="bg-red-100 dark:bg-red-900 p-3 rounded text-sm"><%= reason %></pre>
            <% end %>
          </div>
        <% end %>
        <!-- Help Section -->
        <div class="mt-8 bg-blue-50 dark:bg-blue-900 p-4 rounded-lg">
          <h3 class="font-semibold mb-2">💡 Getting Started</h3>
          <ul class="text-sm space-y-1">
            <li>
              • Make sure ClickHouse is running:
              <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">
                docker-compose up clickhouse
              </code>
            </li>
            <li>
              • Run the setup task:
              <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">mix oli.clickhouse.setup</code>
            </li>
            <li>• Generate video xAPI events by watching videos in the delivery interface</li>
            <li>• Use the sample queries above to analyze video engagement data</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("health_check", _params, socket) do
    health_status = ClickHouseSchema.health_check()
    {:noreply, assign(socket, health_status: health_status)}
  end

  def handle_event("run_sample_query", %{"query" => query_name}, socket) do
    query_name_atom = String.to_existing_atom(query_name)
    query = socket.assigns.sample_queries[query_name_atom]

    socket = assign(socket, executing: true)
    result = execute_query(query)

    {:noreply, assign(socket, query_result: result, executing: false)}
  end

  def handle_event("run_custom_query", %{"custom_query" => query}, socket) do
    socket = assign(socket, executing: true, custom_query: query)
    result = execute_query(query)

    {:noreply, assign(socket, query_result: result, executing: false)}
  end

  defp execute_query(query) when is_binary(query) and byte_size(query) > 0 do
    config = get_clickhouse_config()
    url = "#{config.host}:#{config.port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    case Oli.HTTP.http().post(url, query, headers) do
      {:ok, %{status_code: 200} = response} ->
        {:ok, response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Query failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp execute_query(_), do: {:error, "Empty query"}

  defp humanize_query_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_clickhouse_config() do
    %{
      host: Application.get_env(:oli, :clickhouse_host, "http://localhost"),
      port: Application.get_env(:oli, :clickhouse_port, 8123),
      user: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, "")
    }
  end

  defp breadcrumb(),
    do:
      OliWeb.Admin.AdminView.breadcrumb() ++
        [Breadcrumb.new(%{full_title: "ClickHouse Analytics", link: ~p"/admin/clickhouse"})]
end
