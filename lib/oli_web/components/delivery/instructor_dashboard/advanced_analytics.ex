defmodule OliWeb.Components.Delivery.InstructorDashboard.AdvancedAnalytics do
  use OliWeb, :live_component

  require Logger

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:analytics_data, fn -> nil end)
      |> assign_new(:analytics_spec, fn -> nil end)
      |> assign_new(:custom_sql_query, fn -> nil end)
      |> assign_new(:custom_vega_spec, fn -> nil end)
      |> assign_new(:custom_query_result, fn -> nil end)
      |> assign_new(:custom_visualization_spec, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-2xl font-bold mb-6 text-gray-900 dark:text-white">
          Advanced Analytics Dashboard
        </h1>
        <!-- Comprehensive Section Analytics -->
        <div class="bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
            Event Summary
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
            Overview of all learner activity events in this section.
          </p>

          <%= case @comprehensive_section_analytics do %>
            <% {:ok, result} -> %>
              <div class="text-green-600 dark:text-green-400 mb-3 flex items-center">
                <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
                Analytics data loaded successfully
                <%= if Map.has_key?(result, :execution_time_ms) and is_number(result.execution_time_ms) do %>
                  <span class="ml-2 text-sm text-gray-500 dark:text-gray-400">
                    (executed in <%= :erlang.float_to_binary(result.execution_time_ms / 1, decimals: 2) %>ms)
                  </span>
                <% end %>
              </div>
              <!-- Event Type Cards -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                <%= for line <- String.split(result.body, "\n") |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "event_type"))) do %>
                  <% parts = String.split(line, "\t") %>
                  <%= if length(parts) >= 6 do %>
                    <% [event_type, total_events, unique_users, _earliest, _latest, additional] =
                      Enum.take(parts, 6) %>
                    <div class="bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-2">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300">
                          <%= humanize_event_type(event_type) %>
                        </span>
                      </div>
                      <div>
                        <p class="text-2xl font-bold text-gray-900 dark:text-white">
                          <%= total_events %>
                        </p>
                        <p class="text-sm text-gray-600 dark:text-gray-300">
                          events from <%= unique_users %> users
                        </p>
                        <%= if additional != "" and additional != "0" do %>
                          <p class="text-xs text-blue-600 dark:text-blue-400 mt-1">
                            <%= format_additional_info(event_type, additional) %>
                          </p>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
              <!-- Raw Data Table -->
              <pre class="bg-gray-50 dark:bg-gray-900 border rounded-lg p-4 text-xs overflow-x-auto"><%= result.body %></pre>
            <% {:error, reason} -> %>
              <div class="text-red-600 dark:text-red-400 mb-3 flex items-start">
                <svg class="w-4 h-4 mr-2 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
                Analytics query failed
              </div>
              <div class="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-800 rounded-lg p-4">
                <pre class="text-sm text-red-800 dark:text-red-200 whitespace-pre-wrap"><%= reason %></pre>
              </div>
            <% _ -> %>
              <div class="bg-gray-50 dark:bg-gray-900 border rounded-lg p-4">
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  Loading comprehensive analytics data...
                </p>
              </div>
          <% end %>
        </div>
        <!-- Available Analytics Section -->
        <div class="bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
            Available Analytics
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
            Click on any category below to view detailed analytics and visualizations for this section.
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <button
              phx-click="select_analytics_category"
              phx-value-category="video"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-green-50 to-emerald-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "video", do: "border-green-500", else: "border-transparent hover:border-green-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Video Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Play/pause patterns</li>
                <li>• Completion rates</li>
                <li>• Seek behavior</li>
                <li>• Engagement time</li>
              </ul>
            </button>

            <button
              phx-click="select_analytics_category"
              phx-value-category="assessment"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "assessment", do: "border-blue-500", else: "border-transparent hover:border-blue-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Assessment Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Activity performance</li>
                <li>• Page attempt scores</li>
                <li>• Part-level analysis</li>
                <li>• Success patterns</li>
              </ul>
            </button>

            <button
              phx-click="select_analytics_category"
              phx-value-category="engagement"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-purple-50 to-violet-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "engagement", do: "border-purple-500", else: "border-transparent hover:border-purple-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Engagement Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Page view patterns</li>
                <li>• Content preferences</li>
                <li>• Learning paths</li>
                <li>• Time-based trends</li>
              </ul>
            </button>

            <button
              phx-click="select_analytics_category"
              phx-value-category="performance"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-yellow-50 to-orange-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "performance", do: "border-yellow-500", else: "border-transparent hover:border-yellow-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Performance Insights</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Score distributions</li>
                <li>• Hint usage patterns</li>
                <li>• Feedback effectiveness</li>
                <li>• Learning objective alignment</li>
              </ul>
            </button>

            <button
              phx-click="select_analytics_category"
              phx-value-category="cross_event"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-pink-50 to-rose-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "cross_event", do: "border-pink-500", else: "border-transparent hover:border-pink-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Cross-Event Analysis</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Multi-modal learning</li>
                <li>• Comprehensive summaries</li>
                <li>• User journey mapping</li>
                <li>• Predictive insights</li>
              </ul>
            </button>

            <button
              phx-click="select_analytics_category"
              phx-value-category="custom"
              phx-target={@myself}
              class={[
                "bg-gradient-to-br from-gray-50 to-slate-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4 text-left hover:shadow-lg transition-shadow duration-200 border-2",
                if(@selected_analytics_category == "custom", do: "border-gray-500", else: "border-transparent hover:border-gray-300")
              ]}
            >
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Custom Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Write custom SQL queries</li>
                <li>• Create custom visualizations</li>
                <li>• VegaLite specification editor</li>
                <li>• Direct ClickHouse access</li>
              </ul>
            </button>
          </div>
        </div>

        <!-- Analytics Visualization -->
        <%= if @selected_analytics_category do %>
          <div class="bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-lg p-6">
            <h2 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
              <%= case @selected_analytics_category do %>
                <% "video" -> %> Video Analytics Visualization
                <% "assessment" -> %> Assessment Analytics Visualization
                <% "engagement" -> %> Engagement Analytics Visualization
                <% "performance" -> %> Performance Analytics Visualization
                <% "cross_event" -> %> Cross-Event Analytics Visualization
                <% "custom" -> %> Custom Analytics Builder
                <% _ -> %> Analytics Visualization
              <% end %>
            </h2>


            <!-- Custom Analytics Interface -->
            <%= if @selected_analytics_category == "custom" do %>
              <div class="mb-4">
                <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                  Create custom analytics by writing ClickHouse SQL queries and VegaLite visualization specifications.
                  Query the raw events table directly to answer specific questions about learner behavior.
                </p>
              </div>

              <div class="space-y-6">
                <!-- SQL Query Editor -->
                <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                  <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">ClickHouse SQL Query</h4>
                  <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                    Write a SQL query to fetch data from the analytics database.
                    Use <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">#{Oli.Analytics.AdvancedAnalytics.raw_events_table()}</code> as the table name.
                  </p>
                  <div class="bg-yellow-50 dark:bg-yellow-900 border border-yellow-200 dark:border-yellow-700 rounded-lg p-3 mb-3">
                    <p class="text-sm text-yellow-800 dark:text-yellow-200">
                      <strong>Required:</strong> Your query must include <code class="bg-yellow-100 dark:bg-yellow-800 px-1 rounded">WHERE section_id = {@section.id}</code> to filter results to the current section.
                    </p>
                  </div>
                  <div class="mb-3">
                    <form phx-change="update_custom_field" phx-target={@myself}>
                      <textarea
                        id="custom-sql-query"
                        name="custom_sql_query"
                        class="w-full h-32 p-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white font-mono text-sm"
                        placeholder="SELECT event_type, count(*) as total_events FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()} WHERE section_id = #{@section.id} GROUP BY event_type ORDER BY total_events DESC LIMIT 10"
                      ><%= @custom_sql_query || get_default_sql_query(@section.id) %></textarea>
                    </form>
                  </div>
                  <button
                    phx-click="execute_custom_query"
                    phx-target={@myself}
                    class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition-colors"
                  >
                    Execute Query
                  </button>
                </div>

                <!-- Query Results -->
                <%= if @custom_query_result do %>
                  <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                    <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">Query Results</h4>
                    <%= case @custom_query_result do %>
                      <% {:ok, %{body: body}} -> %>
                        <div class="text-green-600 dark:text-green-400 mb-3 text-sm">✓ Query executed successfully</div>
                        <pre class="bg-white dark:bg-gray-800 border rounded p-3 text-xs overflow-x-auto max-h-40"><%= body %></pre>
                      <% {:error, reason} -> %>
                        <div class="text-red-600 dark:text-red-400 mb-3 text-sm">✗ Query failed</div>
                        <pre class="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded p-3 text-xs text-red-800 dark:text-red-200"><%= reason %></pre>
                    <% end %>
                  </div>
                <% end %>

                <!-- VegaLite Spec Editor -->
                <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                  <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">VegaLite Visualization Spec</h4>
                  <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                    Define a VegaLite specification to visualize your query results. The data will be automatically injected.
                  </p>
                  <div class="mb-3">
                    <form phx-change="update_custom_vega_field" phx-target={@myself}>
                      <textarea
                        id="custom-vega-spec"
                        name="custom_vega_spec"
                        class="w-full h-48 p-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white font-mono text-sm"
                        placeholder='{"mark": "bar", "encoding": {"x": {"field": "event_type", "type": "nominal"}, "y": {"field": "total_events", "type": "quantitative"}}}'
                      ><%= @custom_vega_spec || get_default_vega_spec() %></textarea>
                    </form>
                  </div>
                  <button
                    phx-click="render_custom_visualization"
                    phx-target={@myself}
                    class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm font-medium transition-colors"
                  >
                    Render Visualization
                  </button>
                </div>

                <!-- Custom Visualization -->
                <%= if @custom_visualization_spec do %>
                  <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border">
                    <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white text-center">Custom Visualization</h4>
                    <div class="flex justify-center items-center">
                      <%= {:safe, _chart_html} = OliWeb.Common.React.component(
                        %{is_liveview: true},
                        "Components.VegaLiteRenderer",
                        %{spec: @custom_visualization_spec},
                        id: "custom-analytics-chart"
                      ) %>
                    </div>
                  </div>
                <% end %>
              </div>

            <% else %>

              <!-- Regular Analytics Interface -->
              <%= if @analytics_spec && is_list(@analytics_spec) && length(@analytics_spec) > 0 do %>
                <div class="mb-4">
                  <%= case @selected_analytics_category do %>
                    <% "video" -> %>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        This chart shows video completion rates across the most popular videos in your section.
                        Higher completion rates indicate more engaging content.
                      </p>
                    <% "assessment" -> %>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        This scatter plot shows the relationship between average scores and success rates for activities.
                        Bubble size represents the number of attempts.
                      </p>
                    <% "engagement" -> %>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        These charts show page engagement metrics: the bar chart displays page view counts with completion rates,
                        while the heatmap reveals usage patterns by time of day and day of week.
                      </p>
                    <% "performance" -> %>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        This distribution shows how student scores are spread across different ranges.
                        Color intensity indicates average hint usage.
                      </p>
                    <% "cross_event" -> %>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        This timeline shows the evolution of different event types over time,
                        helping identify usage patterns and trends.
                      </p>
                  <% end %>
                </div>

                <!-- Render all charts vertically -->
                <%= if @analytics_spec && is_list(@analytics_spec) && length(@analytics_spec) > 0 do %>
                  <%= for {chart, index} <- Enum.with_index(@analytics_spec) do %>
                    <div class="mb-6">
                      <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                        <h4 class="text-sm font-medium mb-3 text-gray-700 dark:text-gray-300 text-center"><%= chart.title %></h4>
                        <div class="flex justify-center items-center">
                          <%= {:safe, _chart_html} = OliWeb.Common.React.component(
                            %{is_liveview: true},
                            "Components.VegaLiteRenderer",
                            %{spec: chart.spec},
                            id: "analytics-chart-#{@selected_analytics_category}-#{index}"
                          ) %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% else %>
                  <div class="flex items-center justify-center py-8">
                    <div class="text-center">
                      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
                      <p class="text-gray-500 dark:text-gray-400">Loading analytics data...</p>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <%= if @analytics_data && (
                (@selected_analytics_category == "engagement" && is_map(@analytics_data) &&
                  (length(Map.get(@analytics_data, :bar_chart_data, [])) > 0 || length(Map.get(@analytics_data, :heatmap_data, [])) > 0)) ||
                (@selected_analytics_category != "engagement" && is_list(@analytics_data) && length(@analytics_data) > 0)
              ) do %>
                <div class="mt-6">
                  <h3 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">Raw Data Summary</h3>
                  <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                    <p class="text-sm text-gray-600 dark:text-gray-400 mb-2">
                      <%= if @selected_analytics_category == "engagement" do %>
                        Showing <%= length(Map.get(@analytics_data, :bar_chart_data, [])) %> page engagement records and <%= length(Map.get(@analytics_data, :heatmap_data, [])) %> time-based activity records.
                      <% else %>
                        Showing <%= length(@analytics_data) %> data points for this analysis.
                      <% end %>
                    </p>
                    <details class="text-sm">
                      <summary class="cursor-pointer text-blue-600 dark:text-blue-400 hover:underline">
                        View detailed data
                      </summary>
                      <div class="mt-2 p-3 bg-white dark:bg-gray-800 rounded border">
                        <pre class="text-xs overflow-x-auto"><%= inspect(@analytics_data, pretty: true, limit: :infinity) %></pre>
                      </div>
                    </details>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_analytics_category", %{"category" => category}, socket) do
    # Send message to parent live view to navigate with analytics category parameter
    send(self(), {:select_analytics_category, category})

    # If selecting custom analytics, initialize with default values if not already set
    socket = if category == "custom" do
      socket
      |> assign_new(:custom_sql_query, fn -> get_default_sql_query(socket.assigns.section.id) end)
      |> assign_new(:custom_vega_spec, fn -> get_default_vega_spec() end)
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_custom_query", _params, socket) do
    # Get the current query from assigns, or use default if none exists
    query = case socket.assigns.custom_sql_query do
      nil -> get_default_sql_query(socket.assigns.section.id)
      "" -> get_default_sql_query(socket.assigns.section.id)
      existing_query -> existing_query
    end

    if query && String.trim(query) != "" do
      case validate_query_section_filter(query, socket.assigns.section.id) do
        :ok ->
          result = Oli.Analytics.AdvancedAnalytics.execute_query(query, "custom analytics query")
          {:noreply, assign(socket, custom_query_result: result, custom_sql_query: query)}
        {:error, reason} ->
          error_result = {:error, reason}
          {:noreply, assign(socket, custom_query_result: error_result)}
      end
    else
      error_result = {:error, "Please enter a SQL query"}
      {:noreply, assign(socket, custom_query_result: error_result)}
    end
  end

  @impl true
  def handle_event("render_custom_visualization", _params, socket) do
    %{custom_query_result: query_result, custom_vega_spec: vega_spec} = socket.assigns

    # Use default vega spec if none is provided
    spec_to_use = if vega_spec && String.trim(vega_spec) != "", do: vega_spec, else: get_default_vega_spec()

    case {query_result, spec_to_use} do
      {{:ok, %{body: body}}, spec} when is_binary(spec) and spec != "" ->
        case parse_query_result_and_create_spec(body, spec) do
          {:ok, final_spec} ->
            {:noreply, assign(socket, custom_visualization_spec: final_spec, custom_vega_spec: spec_to_use)}
          {:error, reason} ->
            {:noreply, assign(socket, custom_query_result: {:error, "Visualization error: #{reason}"})}
        end
      _ ->
        error_msg = "Please execute a successful query and provide a VegaLite specification"
        {:noreply, assign(socket, custom_query_result: {:error, error_msg})}
    end
  end

  @impl true
  def handle_event("update_custom_field", %{"custom_sql_query" => value}, socket) do
    {:noreply, assign(socket, custom_sql_query: value)}
  end

  @impl true
  def handle_event("update_custom_vega_field", %{"custom_vega_spec" => value}, socket) do
    {:noreply, assign(socket, custom_vega_spec: value)}
  end

  @impl true
  def handle_event("update_custom_field", params, socket) do
    # Debug log to see what structure we're getting
    Logger.info("update_custom_field params: #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_custom_vega_field", params, socket) do
    # Debug log to see what structure we're getting
    Logger.info("update_custom_vega_field params: #{inspect(params)}")
    {:noreply, socket}
  end

  # Helper functions for custom analytics
  defp validate_query_section_filter(query, current_section_id) do
    # Normalize the query for easier parsing
    normalized_query = query
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()

    # Check if there's a WHERE clause
    unless String.contains?(normalized_query, "where") do
      {:error, "Query must include a WHERE clause to filter results to the current section"}
    else
      # Extract the WHERE clause and everything after it
      case String.split(normalized_query, "where", parts: 2) do
        [_before_where] ->
          {:error, "Query must include a WHERE clause to filter results to the current section"}
        [_before_where, where_clause] ->
          validate_section_id_in_where_clause(where_clause, current_section_id)
      end
    end
  end

  defp validate_section_id_in_where_clause(where_clause, current_section_id) do
    # Check for section_id filter patterns (with and without quotes)
    section_id_patterns = [
      ~r/section_id\s*=\s*#{current_section_id}(\s|$|and|or|group|order|limit|having)/,
      ~r/section_id\s*=\s*'#{current_section_id}'(\s|$|and|or|group|order|limit|having)/,
      ~r/section_id\s*=\s*"#{current_section_id}"(\s|$|and|or|group|order|limit|having)/
    ]

    section_filter_found = Enum.any?(section_id_patterns, fn pattern ->
      Regex.match?(pattern, where_clause)
    end)

    if section_filter_found do
      :ok
    else
      # Check if section_id is mentioned but with wrong value
      if String.contains?(where_clause, "section_id") do
        {:error, "Query contains section_id filter but with incorrect value. Must be: WHERE section_id = #{current_section_id}"}
      else
        {:error, "Query must filter results to the current section (WHERE section_id = #{current_section_id})"}
      end
    end
  end

  defp get_default_sql_query(section_id) do
    """
    SELECT
      event_type,
      count(*) as total_events,
      uniq(user_id) as unique_users
    FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
    WHERE section_id = #{section_id}
    GROUP BY event_type
    ORDER BY total_events DESC
    LIMIT 10
    """
  end

  defp get_default_vega_spec() do
    """
    {
      "mark": {"type": "bar", "tooltip": true},
      "encoding": {
        "x": {
          "field": "event_type",
          "type": "nominal",
          "title": "Event Type"
        },
        "y": {
          "field": "total_events",
          "type": "quantitative",
          "title": "Total Events"
        },
        "color": {
          "field": "total_events",
          "type": "quantitative",
          "scale": {"scheme": "blues"}
        }
      },
      "width": 600,
      "height": 300,
      "title": "Event Distribution"
    }
    """
  end

  defp parse_query_result_and_create_spec(query_body, vega_spec_string) do
    try do
      # Debug: Log the raw query body
      Logger.info("=== CUSTOM ANALYTICS DEBUG ===")
      Logger.info("Raw query body: #{inspect(query_body, limit: :infinity)}")

      # Parse the TSV data from the query result
      data = parse_tsv_data(query_body)
      Logger.info("Parsed TSV data: #{inspect(data, limit: :infinity)}")

      # Convert data to the format expected by VegaLite (list of maps)
      chart_data = case data do
        [] ->
          Logger.info("Data is empty!")
          []
        [header | rows] when is_list(header) ->
          Logger.info("Found header: #{inspect(header)}")
          Logger.info("Found #{length(rows)} data rows")
          # If we got headers and rows, use the headers as keys
          result = Enum.map(rows, fn row ->
            Logger.info("Processing row: #{inspect(row)}")
            header
            |> Enum.zip(row)
            |> Enum.into(%{})
          end)
          Logger.info("Converted to maps: #{inspect(result, limit: :infinity)}")
          result
        rows ->
          Logger.info("No header detected, rows: #{inspect(rows, limit: :infinity)}")
          # Try to infer column names from first row
          case List.first(rows) do
            [first | _] when is_binary(first) ->
              # Try to detect if first row contains headers
              if Regex.match?(~r/^[a-zA-Z_][a-zA-Z0-9_]*$/, first) do
                Logger.info("First row looks like headers: #{inspect(first)}")
                # Looks like a header row
                [header | data_rows] = rows
                result = Enum.map(data_rows, fn row ->
                  header
                  |> Enum.zip(row)
                  |> Enum.into(%{})
                end)
                Logger.info("Using detected headers, result: #{inspect(result, limit: :infinity)}")
                result
              else
                Logger.info("First row doesn't look like headers, generating generic names")
                # Generate generic column names
                first_row = List.first(rows)
                headers = Enum.with_index(first_row) |> Enum.map(fn {_, i} -> "col_#{i}" end)
                Logger.info("Generated headers: #{inspect(headers)}")
                result = Enum.map(rows, fn row ->
                  headers
                  |> Enum.zip(row)
                  |> Enum.into(%{})
                end)
                Logger.info("Result with generic headers: #{inspect(result, limit: :infinity)}")
                result
              end
            _ ->
              Logger.info("Could not process first row")
              []
          end
      end

      # Parse the VegaLite spec
      Logger.info("VegaLite spec string: #{inspect(vega_spec_string)}")
      base_spec = Jason.decode!(vega_spec_string)
      Logger.info("Parsed VegaLite spec: #{inspect(base_spec, limit: :infinity)}")

      # Inject the data into the spec
      final_spec = Map.put(base_spec, "data", %{"values" => chart_data})
      Logger.info("Final spec with data: #{inspect(final_spec, limit: :infinity)}")

      # Convert to VegaLite spec format
      vega_spec = VegaLite.from_json(Jason.encode!(final_spec)) |> VegaLite.to_spec()
      Logger.info("Final VegaLite spec: #{inspect(vega_spec, limit: :infinity)}")
      Logger.info("=== END CUSTOM ANALYTICS DEBUG ===")

      {:ok, vega_spec}
    rescue
      e ->
        Logger.error("Custom analytics visualization error: #{Exception.message(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        {:error, "Failed to parse data or create visualization: #{Exception.message(e)}"}
    end
  end

  # Private functions moved from main module
  def get_analytics_data_and_spec("video", section_id) do
    query = """
      SELECT
        content_element_id,
        video_title,
        countIf(video_time IS NOT NULL) as plays,
        countIf(video_progress >= 0.8) as completions,
        if(plays > 0, completions / plays * 100, 0) as completion_rate,
        avg(video_progress) as avg_progress,
        uniq(user_id) as unique_viewers
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'video' AND video_title IS NOT NULL
      GROUP BY content_element_id, video_title
      HAVING plays >= 1
      ORDER BY plays DESC
      LIMIT 20
    """

    case Oli.Analytics.AdvancedAnalytics.execute_query(query, "video analytics") do
      {:ok, %{body: body}} ->
        data = parse_tsv_data(body)

        Logger.info("Video analytics data: #{inspect(data, limit: :infinity)}")

        if length(data) > 0 do
          spec = create_video_completion_chart(data)
          Logger.info("Video analytics spec: #{inspect(spec, limit: :infinity)}")
          charts = [%{title: "Video Completion Analysis", spec: spec}]
          {data, charts}
        else
          # Create dummy data if no real data exists
          dummy_data = [
            ["1", "Introduction Video", "25", "20", "80.0", "0.85", "15"],
            ["2", "Tutorial Part 1", "18", "12", "66.7", "0.72", "12"],
            ["3", "Practice Session", "30", "22", "73.3", "0.78", "18"]
          ]
          spec = create_video_completion_chart(dummy_data)
          Logger.info("Using dummy video data")
          charts = [%{title: "Video Completion Analysis", spec: spec}]
          {dummy_data, charts}
        end

      {:error, reason} ->
        Logger.error("Video analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("assessment", section_id) do
    query = """
      SELECT
        activity_id,
        count(*) as total_attempts,
        avg(scaled_score) as avg_score,
        countIf(success = true) as successful_attempts,
        uniq(user_id) as unique_users
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type IN ('activity_attempt', 'page_attempt') AND activity_id IS NOT NULL
      GROUP BY activity_id
      HAVING total_attempts >= 1
      ORDER BY total_attempts DESC
      LIMIT 20
    """

    case Oli.Analytics.AdvancedAnalytics.execute_query(query, "assessment analytics") do
      {:ok, %{body: body}} ->
        data = parse_tsv_data(body)

        if length(data) > 0 do
          spec = create_assessment_performance_chart(data)
          charts = [%{title: "Assessment Performance Analysis", spec: spec}]
          {data, charts}
        else
          # Create dummy data
          dummy_data = [
            ["1", "45", "0.75", "35", "20"],
            ["2", "38", "0.82", "30", "18"],
            ["3", "52", "0.68", "28", "25"]
          ]
          spec = create_assessment_performance_chart(dummy_data)
          charts = [%{title: "Assessment Performance Analysis", spec: spec}]
          {dummy_data, charts}
        end

      {:error, reason} ->
        Logger.error("Assessment analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("engagement", section_id) do
    # Main engagement query for bar chart
    query = """
      SELECT
        page_id,
        page_sub_type,
        count(*) as total_views,
        uniq(user_id) as unique_viewers,
        countIf(completion = true) as completed_views,
        if(total_views > 0, completed_views / total_views * 100, 0) as completion_rate
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'page_viewed' AND page_id IS NOT NULL
      GROUP BY page_id, page_sub_type
      HAVING total_views >= 1
      ORDER BY total_views DESC
      LIMIT 20
    """

    # Heatmap query for time-based analysis
    heatmap_query = """
      SELECT
        page_id,
        toDate(timestamp) as date,
        count(*) as view_count
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'page_viewed'
      GROUP BY page_id, date
      ORDER BY page_id, date
    """

    case Oli.Analytics.AdvancedAnalytics.execute_query(query, "engagement analytics") do
      {:ok, %{body: body}} ->
        data = parse_tsv_data(body)

        # Get heatmap data
        heatmap_data = case Oli.Analytics.AdvancedAnalytics.execute_query(heatmap_query, "engagement heatmap") do
          {:ok, %{body: heatmap_body}} -> parse_tsv_data(heatmap_body)
          {:error, _} -> []
        end

        if length(data) > 0 || length(heatmap_data) > 0 do
          bar_spec = create_page_engagement_chart(data)
          heatmap_spec = create_engagement_heatmap_chart(heatmap_data)

          # Return both charts as a list
          combined_data = %{
            bar_chart_data: data,
            heatmap_data: heatmap_data
          }

          charts = [
            %{title: "Page Engagement", spec: bar_spec},
            %{title: "Activity Heatmap", spec: heatmap_spec}
          ]

          {combined_data, charts}
        else
          # Create dummy data for both charts
          dummy_data = [
            ["1", "lesson", "125", "45", "98", "78.4"],
            ["2", "assessment", "89", "38", "67", "75.3"],
            ["3", "reading", "156", "52", "134", "85.9"]
          ]

          dummy_heatmap_data = [
            ["page_1", "2024-09-02", "15"],   # Page 1, Sept 2, 15 views
            ["page_1", "2024-09-09", "23"],   # Page 1, Sept 9, 23 views
            ["page_1", "2024-09-16", "18"],   # Page 1, Sept 16, 18 views
            ["page_2", "2024-09-03", "12"],   # Page 2, Sept 3, 12 views
            ["page_2", "2024-09-10", "19"],   # Page 2, Sept 10, 19 views
            ["page_2", "2024-09-17", "25"],   # Page 2, Sept 17, 25 views
            ["page_3", "2024-09-04", "22"],   # Page 3, Sept 4, 22 views
            ["page_3", "2024-09-11", "28"],   # Page 3, Sept 11, 28 views
            ["page_3", "2024-09-18", "31"],   # Page 3, Sept 18, 31 views
            ["page_4", "2024-09-05", "17"],   # Page 4, Sept 5, 17 views
            ["page_4", "2024-09-12", "21"],   # Page 4, Sept 12, 21 views
            ["page_4", "2024-09-19", "16"],   # Page 4, Sept 19, 16 views
            ["page_5", "2024-09-06", "8"],    # Page 5, Sept 6, 8 views
            ["page_5", "2024-09-13", "14"],   # Page 5, Sept 13, 14 views
            ["page_5", "2024-09-20", "12"]    # Page 5, Sept 20, 12 views
          ]

          bar_spec = create_page_engagement_chart(dummy_data)
          heatmap_spec = create_engagement_heatmap_chart(dummy_heatmap_data)

          combined_data = %{
            bar_chart_data: dummy_data,
            heatmap_data: dummy_heatmap_data
          }

          charts = [
            %{title: "Page Engagement", spec: bar_spec},
            %{title: "Activity Heatmap", spec: heatmap_spec}
          ]

          Logger.info("Using dummy engagement data")
          {combined_data, charts}
        end

      {:error, reason} ->
        Logger.error("Engagement analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("performance", section_id) do
    query = """
      SELECT
        if(scaled_score <= 0.2, '0-20%',
           if(scaled_score <= 0.4, '21-40%',
              if(scaled_score <= 0.6, '41-60%',
                 if(scaled_score <= 0.8, '61-80%', '81-100%')))) as score_range,
        count(*) as attempt_count,
        avg(hints_requested) as avg_hints
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'part_attempt' AND scaled_score IS NOT NULL
      GROUP BY score_range
      ORDER BY score_range
    """

    case Oli.Analytics.AdvancedAnalytics.execute_query(query, "performance analytics") do
      {:ok, %{body: body}} ->
        data = parse_tsv_data(body)

        if length(data) > 0 do
          spec = create_score_distribution_chart(data)
          charts = [%{title: "Score Distribution Analysis", spec: spec}]
          {data, charts}
        else
          # Create dummy data for score distribution
          dummy_data = [
            ["0-20%", "15", "2.8"],
            ["21-40%", "42", "3.2"],
            ["41-60%", "78", "2.1"],
            ["61-80%", "124", "1.4"],
            ["81-100%", "89", "0.6"]
          ]
          spec = create_score_distribution_chart(dummy_data)
          Logger.info("Using dummy performance data")
          charts = [%{title: "Score Distribution Analysis", spec: spec}]
          {dummy_data, charts}
        end

      {:error, reason} ->
        Logger.error("Performance analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("cross_event", section_id) do
    query = """
      SELECT
        event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        toYYYYMM(timestamp) as month
      FROM #{Oli.Analytics.AdvancedAnalytics.raw_events_table()}
      WHERE section_id = #{section_id}
      GROUP BY event_type, month
      ORDER BY month DESC, event_type
      LIMIT 100
    """

    case Oli.Analytics.AdvancedAnalytics.execute_query(query, "cross-event analytics") do
      {:ok, %{body: body}} ->
        data = parse_tsv_data(body)

        if length(data) > 0 do
          spec = create_event_timeline_chart(data)
          charts = [%{title: "Event Timeline Analysis", spec: spec}]
          {data, charts}
        else
          # Create dummy data for event timeline
          dummy_data = [
            ["video", "245", "35", "202409"],
            ["page_viewed", "1567", "42", "202409"],
            ["activity_attempt", "387", "38", "202409"],
            ["part_attempt", "892", "38", "202409"],
            ["video", "198", "33", "202408"],
            ["page_viewed", "1234", "40", "202408"],
            ["activity_attempt", "298", "35", "202408"],
            ["part_attempt", "756", "35", "202408"],
            ["video", "156", "28", "202407"],
            ["page_viewed", "987", "35", "202407"],
            ["activity_attempt", "234", "32", "202407"],
            ["part_attempt", "623", "32", "202407"]
          ]
          spec = create_event_timeline_chart(dummy_data)
          Logger.info("Using dummy cross-event data")
          charts = [%{title: "Event Timeline Analysis", spec: spec}]
          {dummy_data, charts}
        end

      {:error, reason} ->
        Logger.error("Cross-event analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("custom", _section_id) do
    # For custom analytics, we don't preload data since users will provide their own queries
    {[], []}
  end

  def get_analytics_data_and_spec(_, _), do: {[], []}

  defp parse_tsv_data(body) when is_binary(body) do
    Logger.info("=== TSV PARSING DEBUG ===")
    Logger.info("Raw body: #{inspect(body)}")

    lines = String.split(String.trim(body), "\n")
    Logger.info("Split into #{length(lines)} lines: #{inspect(lines)}")

    result = case lines do
      [] ->
        Logger.info("No lines found")
        []

      [header | data_lines] ->
        Logger.info("Header line: #{inspect(header)}")
        Logger.info("Data lines: #{inspect(data_lines)}")

        # Parse header to handle both pipe and tab separators
        header_columns = if String.contains?(header, "|") do
          String.split(header, "|") |> Enum.map(&String.trim/1)
        else
          String.split(header, "\t")
        end
        Logger.info("Parsed header columns: #{inspect(header_columns)}")

        filtered_lines = data_lines
        |> Enum.filter(fn line ->
          # Filter out separator lines that contain only dashes and pipes
          not String.match?(line, ~r/^[\s\-\|]+$/)
        end)

        Logger.info("After filtering separators: #{inspect(filtered_lines)}")

        parsed_data = filtered_lines
        |> Enum.map(fn line ->
          # Check if the line contains pipes or tabs and split accordingly
          parsed = if String.contains?(line, "|") do
            String.split(line, "|") |> Enum.map(&String.trim/1)
          else
            String.split(line, "\t")
          end
          Logger.info("Parsed line '#{line}' into: #{inspect(parsed)}")
          parsed
        end)

        Logger.info("Final parsed data: #{inspect(parsed_data)}")

        # Return as [header_columns, ...data_rows] format expected by parse_query_result_and_create_spec
        [header_columns | parsed_data]
    end

    Logger.info("=== END TSV PARSING DEBUG ===")
    result
  end

  # Chart creation functions...
  defp create_video_completion_chart(data) do
    chart_data =
      Enum.take(data, 10)
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        [_id, title, plays, _completions, completion_rate, _avg_progress, _viewers] =
          case row do
            list when is_list(list) -> list
            _ -> ["", "Unknown", "0", "0", "0", "0", "0"]
          end

        %{
          "video" => "Video #{idx + 1}",
          "title" => String.slice(title || "Unknown", 0, 20),
          "completion_rate" => case completion_rate do
            rate when is_binary(rate) ->
              case Float.parse(rate) do
                {float_val, _} -> float_val
                :error -> 0.0
              end
            rate when is_number(rate) -> rate
            _ -> 0.0
          end,
          "plays" => case plays do
            p when is_binary(p) ->
              case Integer.parse(p) do
                {int_val, _} -> int_val
                :error -> 0
              end
            p when is_number(p) -> p
            _ -> 0
          end
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": 600,
      "height": 300,
      "title": "Video Completion Rates",
      "description": "Video completion rates across the most popular videos",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "bar",
        "tooltip": true
      },
      "encoding": {
        "x": {
          "field": "video",
          "type": "nominal",
          "title": "Videos",
          "axis": {
            "labelAngle": 0
          }
        },
        "y": {
          "field": "completion_rate",
          "type": "quantitative",
          "title": "Completion Rate (%)"
        },
        "color": {
          "field": "completion_rate",
          "type": "quantitative",
          "scale": {
            "scheme": "blues"
          },
          "title": "Completion Rate"
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_assessment_performance_chart(data) do
    chart_data =
      Enum.take(data, 10)
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        [activity_id, attempts, avg_score, successful, _users] =
          case row do
            list when is_list(list) -> list
            _ -> ["", "0", "0", "0", "0"]
          end

        attempts_num = case attempts do
          a when is_binary(a) ->
            case Integer.parse(a) do
              {int_val, _} -> int_val
              :error -> 0
            end
          a when is_number(a) -> a
          _ -> 0
        end

        avg_score_num = case avg_score do
          s when is_binary(s) ->
            case Float.parse(s) do
              {float_val, _} -> float_val * 100
              :error -> 0.0
            end
          s when is_number(s) -> s * 100
          _ -> 0.0
        end

        successful_num = case successful do
          s when is_binary(s) ->
            case Integer.parse(s) do
              {int_val, _} -> int_val
              :error -> 0
            end
          s when is_number(s) -> s
          _ -> 0
        end

        success_rate = if attempts_num > 0, do: successful_num / attempts_num * 100, else: 0

        %{
          "activity" => "Activity #{idx + 1}",
          "activity_id" => activity_id || "Unknown",
          "avg_score" => avg_score_num,
          "success_rate" => success_rate,
          "attempts" => attempts_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": 600,
      "height": 300,
      "title": "Assessment Performance",
      "description": "Assessment performance metrics",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "circle",
        "size": 100,
        "tooltip": true
      },
      "encoding": {
        "x": {
          "field": "avg_score",
          "type": "quantitative",
          "title": "Average Score (%)"
        },
        "y": {
          "field": "success_rate",
          "type": "quantitative",
          "title": "Success Rate (%)"
        },
        "size": {
          "field": "attempts",
          "type": "quantitative",
          "title": "Total Attempts"
        },
        "color": {
          "field": "avg_score",
          "type": "quantitative",
          "scale": {
            "scheme": "blues"
          },
          "title": "Avg Score"
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_page_engagement_chart(data) do
    chart_data =
      Enum.take(data, 15)
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        [page_id, page_type, views, viewers, _completed, completion_rate] =
          case row do
            list when is_list(list) -> list
            _ -> ["", "Unknown", "0", "0", "0", "0"]
          end

        views_num = case views do
          v when is_binary(v) ->
            case Integer.parse(v) do
              {int_val, _} -> int_val
              :error -> 0
            end
          v when is_number(v) -> v
          _ -> 0
        end

        viewers_num = case viewers do
          v when is_binary(v) ->
            case Integer.parse(v) do
              {int_val, _} -> int_val
              :error -> 0
            end
          v when is_number(v) -> v
          _ -> 0
        end

        completion_rate_num = case completion_rate do
          r when is_binary(r) ->
            case Float.parse(r) do
              {float_val, _} -> float_val
              :error -> 0.0
            end
          r when is_number(r) -> r
          _ -> 0.0
        end

        %{
          "page" => "Page #{idx + 1}",
          "page_id" => page_id || "Unknown",
          "page_type" => page_type || "Unknown",
          "views" => views_num,
          "unique_viewers" => viewers_num,
          "completion_rate" => completion_rate_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": 600,
      "height": 300,
      "title": "Page Engagement Metrics",
      "description": "Page view counts and completion rates",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "bar",
        "tooltip": true
      },
      "encoding": {
        "x": {
          "field": "page",
          "type": "nominal",
          "title": "Pages",
          "axis": {
            "labelAngle": -45
          }
        },
        "y": {
          "field": "views",
          "type": "quantitative",
          "title": "Total Views"
        },
        "color": {
          "field": "completion_rate",
          "type": "quantitative",
          "scale": {
            "scheme": "oranges"
          },
          "title": "Completion Rate (%)"
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_engagement_heatmap_chart(data) do
    chart_data =
      Enum.map(data, fn row ->
        [page_id, date, total_views] =
          case row do
            list when is_list(list) -> list
            _ -> ["unknown", "2024-01-01", "0"]
          end

        views_num = case total_views do
          v when is_binary(v) ->
            case Integer.parse(v) do
              {int_val, _} -> int_val
              :error -> 0
            end
          v when is_number(v) -> v
          _ -> 0
        end

        %{
          "page_id" => page_id || "unknown",
          "date" => date || "2024-01-01",
          "total_views" => views_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": {"step": 40},
      "height": {"step": 40},
      "title": "Page Views Heatmap by Date",
      "description": "Heatmap showing page view intensity by page and date",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "rect",
        "tooltip": true,
        "stroke": "white",
        "strokeWidth": 0  // Set to 0 to avoid visible borders on heatmap cells
      },
      "encoding": {
        "x": {
          "field": "date",
          "type": "ordinal",
          "title": "Date",
          "axis": {
            "labelAngle": -45,
            "grid": false
          },
          "scale": {
            "type": "band",
            "paddingInner": 0.0
          }
        },
        "y": {
          "field": "page_id",
          "type": "ordinal",
          "title": "Page ID",
          "axis": {
            "grid": false,
            "labelLimit": 100
          },
          "sort": null,
          "scale": {
            "type": "band",
            "paddingInner": 0.1
          }
        },
        "color": {
          "field": "total_views",
          "type": "quantitative",
          // Restored original color palette for consistency with other charts
          "scale": {
            "scheme": "blues",
            "type": "linear",
            "nice": true,
            "zero": true
          },
          "legend": {
            "title": "Page Views",
            "titleFontSize": 12,
            "gradientLength": 200,
            "orient": "right"
          }
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_score_distribution_chart(data) do
    chart_data =
      Enum.map(data, fn row ->
        [score_range, count, avg_hints] =
          case row do
            list when is_list(list) -> list
            _ -> ["Unknown", "0", "0"]
          end

        count_num = case count do
          c when is_binary(c) ->
            case Integer.parse(c) do
              {int_val, _} -> int_val
              :error -> 0
            end
          c when is_number(c) -> c
          _ -> 0
        end

        hints_num = case avg_hints do
          h when is_binary(h) ->
            case Float.parse(h) do
              {float_val, _} -> float_val
              :error -> 0.0
            end
          h when is_number(h) -> h
          _ -> 0.0
        end

        %{
          "score_range" => score_range || "Unknown",
          "count" => count_num,
          "avg_hints" => hints_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": 600,
      "height": 300,
      "title": "Score Distribution and Hint Usage",
      "description": "Distribution of student scores with average hint usage",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "bar",
        "tooltip": true
      },
      "encoding": {
        "x": {
          "field": "score_range",
          "type": "ordinal",
          "title": "Score Range",
          "sort": ["0-20%", "21-40%", "41-60%", "61-80%", "81-100%"]
        },
        "y": {
          "field": "count",
          "type": "quantitative",
          "title": "Number of Attempts"
        },
        "color": {
          "field": "avg_hints",
          "type": "quantitative",
          "scale": {
            "scheme": "reds"
          },
          "title": "Avg Hints Used"
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_event_timeline_chart(data) do
    chart_data =
      Enum.map(data, fn row ->
        [event_type, count, users, month] =
          case row do
            list when is_list(list) -> list
            _ -> ["unknown", "0", "0", "202401"]
          end

        month_str = month || "202401"
        year = String.slice(month_str, 0, 4)
        month_num = String.slice(month_str, 4, 2)

        count_num = case count do
          c when is_binary(c) ->
            case Integer.parse(c) do
              {int_val, _} -> int_val
              :error -> 0
            end
          c when is_number(c) -> c
          _ -> 0
        end

        users_num = case users do
          u when is_binary(u) ->
            case Integer.parse(u) do
              {int_val, _} -> int_val
              :error -> 0
            end
          u when is_number(u) -> u
          _ -> 0
        end

        %{
          "event_type" => event_type || "unknown",
          "count" => count_num,
          "users" => users_num,
          "month" => "#{year}-#{month_num}-01"
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    VegaLite.from_json("""
    {
      "width": 600,
      "height": 300,
      "title": "Event Activity Timeline",
      "description": "Timeline showing different event types over time",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "line",
        "point": true,
        "tooltip": true
      },
      "encoding": {
        "x": {
          "field": "month",
          "type": "temporal",
          "title": "Month",
          "axis": {
            "format": "%Y-%m"
          }
        },
        "y": {
          "field": "count",
          "type": "quantitative",
          "title": "Event Count"
        },
        "color": {
          "field": "event_type",
          "type": "nominal",
          "title": "Event Type",
          "scale": {
            "scheme": "category10"
          }
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  # Helper functions for formatting analytics display
  defp humanize_event_type(event_type) do
    case event_type do
      "video" -> "Video Interactions"
      "activity_attempt" -> "Activity Attempts"
      "page_attempt" -> "Page Assessments"
      "page_viewed" -> "Page Views"
      "part_attempt" -> "Question Attempts"
      # Legacy event type names for backward compatibility
      "video_events" -> "Video Interactions"
      "activity_attempts" -> "Activity Attempts"
      "page_attempts" -> "Page Assessments"
      "page_views" -> "Page Views"
      "part_attempts" -> "Question Attempts"
      _ -> String.replace(event_type, "_", " ") |> String.capitalize()
    end
  end

  defp format_additional_info(event_type, additional) do
    case event_type do
      "activity_attempt" -> "Avg score: #{additional}"
      "page_attempt" -> "Avg score: #{additional}"
      "page_viewed" -> "#{additional} completed"
      "part_attempt" -> "Avg score: #{additional}"
      # Legacy event type names for backward compatibility
      "activity_attempts" -> "Avg score: #{additional}"
      "page_attempts" -> "Avg score: #{additional}"
      "page_views" -> "#{additional} completed"
      "part_attempts" -> "Avg score: #{additional}"
      _ -> additional
    end
  end
end
