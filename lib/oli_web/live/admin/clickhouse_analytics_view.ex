defmodule OliWeb.Admin.ClickHouseAnalyticsView do
  use OliWeb, :live_view

  alias Oli.Analytics.ClickhouseAnalytics
  alias OliWeb.Common.Breadcrumb
  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    sample_queries = ClickhouseAnalytics.sample_analytics_queries()

    {:ok, assign(socket,
      title: "ClickHouse Analytics",
      breadcrumb: breadcrumb(),
      health_status: nil,
      query_result: nil,
      selected_query: "",
      custom_query: "",
      executing: false,
      sample_queries: sample_queries,
      dropdown_options: build_dropdown_options(sample_queries)
    )}
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
        <!-- Query Selection and Execution Section -->
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <h2 class="text-xl font-semibold mb-4">Analytics Query</h2>

          <.form for={%{}} as={:query_form} phx-change="query_selected" phx-submit="execute_query">
            <div class="mb-4">
              <label class="block text-sm font-medium mb-2">Select Query:</label>
              <select
                name="selected_query"
                class="w-full p-3 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                value={@selected_query}
              >
                <option value="">-- Select a query --</option>
                <%= for {value, label} <- @dropdown_options do %>
                  <option value={value} selected={@selected_query == value}>
                    <%= label %>
                  </option>
                <% end %>
              </select>
            </div>

            <%= if @selected_query != "" do %>
            <%= if @selected_query == "custom" do %>
              <div class="mb-4">
                <label class="block text-sm font-medium mb-2">Custom Query:</label>
                <div phx-update="ignore" id="custom-query-container">
                  <textarea
                    id="custom_query_textarea"
                    name="custom_query"
                    rows="6"
                    class="w-full p-3 border rounded-lg dark:bg-gray-700 dark:border-gray-600 font-mono text-sm"
                    placeholder="Enter your ClickHouse SQL query here..."
                  ><%= @custom_query %></textarea>
                </div>
              </div>

            <% else %>
                <p class="text-gray-600 dark:text-gray-400"><%= get_query_description(@selected_query, @sample_queries) %></p>

              <div class="my-4 p-3 bg-gray-100 dark:bg-gray-700 rounded-lg">
                <pre class="text-xs overflow-x-auto"><%= get_query_text(@selected_query, @sample_queries) %></pre>
              </div>
            <% end %>

              <div class="flex items-center gap-4">
                <.button type="submit" class="btn-primary" disabled={@executing}>
                  <%= if @executing, do: "Executing...", else: "Execute Query" %>
                </.button>
              </div>
            <% end %>

          </.form>
        </div>
        <!-- Results Section -->
        <%= if @query_result do %>
          <div class="bg-white dark:bg-gray-800 border dark:border-gray-600 rounded-lg p-4">
            <h2 class="text-xl font-semibold mb-4">Query Results</h2>

            <%= case @query_result do %>
              <% {:ok, result} -> %>
                <div class="text-green-600 dark:text-green-400 mb-2 flex items-center">
                  ✅ Query executed successfully
                  <%= if Map.has_key?(result, :execution_time_ms) and is_number(result.execution_time_ms) do %>
                    <span class="ml-2 text-sm text-gray-500 dark:text-gray-400">
                      (executed in <%= :erlang.float_to_binary(result.execution_time_ms / 1, decimals: 2) %>ms)
                    </span>
                  <% end %>
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
      </div>
    </div>
    """
  end

  def handle_event("health_check", _params, socket) do
    health_status = ClickhouseAnalytics.health_check()
    {:noreply, assign(socket, health_status: health_status)}
  end

  def handle_event("query_selected", params, socket) do
    selected_query = Map.get(params, "selected_query", "")
    custom_query = Map.get(params, "custom_query", socket.assigns.custom_query)

    {:noreply, assign(socket, selected_query: selected_query, custom_query: custom_query)}
  end

  def handle_event("execute_query", params, socket) do
    selected_query = Map.get(params, "selected_query", socket.assigns.selected_query)
    custom_query = Map.get(params, "custom_query", socket.assigns.custom_query)

    # Preserve the custom_query value regardless of execution
    socket = assign(socket, executing: true, custom_query: custom_query)

    result = case selected_query do
      "custom" ->
        ClickhouseAnalytics.execute_query(custom_query, "Custom Query")
      query_name when query_name != "" ->
        query_name_atom = String.to_existing_atom(query_name)
        query_data = socket.assigns.sample_queries[query_name_atom]
        query_text = if is_map(query_data), do: query_data.query, else: query_data
        ClickhouseAnalytics.execute_query(query_text, query_name_atom)
      _ ->
        {:error, "No query selected"}
    end

    # Ensure custom_query is preserved after execution
    {:noreply, assign(socket, query_result: result, executing: false, custom_query: custom_query)}
  end

  # Legacy event handlers for backward compatibility
  def handle_event("run_sample_query", %{"query" => query_name}, socket) do
    query_name_atom = String.to_existing_atom(query_name)
    query_data = socket.assigns.sample_queries[query_name_atom]
    query_text = if is_map(query_data), do: query_data.query, else: query_data

    socket = assign(socket, executing: true)
    result = ClickhouseAnalytics.execute_query(query_text, query_name_atom)

    {:noreply, assign(socket, query_result: result, executing: false)}
  end

  def handle_event("run_custom_query", %{"custom_query" => query}, socket) do
    socket = assign(socket, executing: true, custom_query: query)
    result = ClickhouseAnalytics.execute_query(query, "Custom Query")

    # Preserve the custom query text after execution
    {:noreply, assign(socket, query_result: result, executing: false, custom_query: query)}
  end

  defp build_dropdown_options(sample_queries) do
    sample_options =
      sample_queries
      |> Enum.map(fn {key, _query_data} ->
        {Atom.to_string(key), ClickhouseAnalytics.humanize_query_name(key)}
      end)
      |> Enum.sort_by(fn {_key, label} -> label end)

    sample_options ++ [{"custom", "Custom Query"}]
  end

  defp get_query_text(selected_query, sample_queries) do
    case String.to_existing_atom(selected_query) do
      query_name when is_map_key(sample_queries, query_name) ->
        query_data = sample_queries[query_name]
        query_text = if is_map(query_data), do: query_data.query, else: query_data
        query_text |> String.trim()
      _ ->
        ""
    end
  rescue
    ArgumentError -> ""
  end

  defp get_query_description(selected_query, sample_queries) do
    case String.to_existing_atom(selected_query) do
      query_name when is_map_key(sample_queries, query_name) ->
        query_data = sample_queries[query_name]
        if is_map(query_data), do: query_data.description, else: "No description available"
      _ ->
        ""
    end
  rescue
    ArgumentError -> ""
  end

  defp breadcrumb(),
    do:
      OliWeb.Admin.AdminView.breadcrumb() ++
        [Breadcrumb.new(%{full_title: "ClickHouse Analytics", link: ~p"/admin/clickhouse"})]
end
