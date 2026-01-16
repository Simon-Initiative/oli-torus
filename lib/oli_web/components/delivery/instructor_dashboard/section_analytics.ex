defmodule OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics do
  use OliWeb, :live_component

  alias OliWeb.Common.Monaco

  require Logger

  @summary_event_type_order [
    "video",
    "activity_attempt",
    "page_attempt",
    "page_viewed",
    "part_attempt"
  ]

  @legacy_event_type_map %{
    "video_events" => "video",
    "activity_attempts" => "activity_attempt",
    "page_attempts" => "page_attempt",
    "page_views" => "page_viewed",
    "part_attempts" => "part_attempt"
  }

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
      |> assign_new(:section_analytics_load_state, fn -> :loaded end)
      |> assign_new(:custom_sql_query, fn -> nil end)
      |> assign_new(:custom_vega_spec, fn -> nil end)
      |> assign_new(:custom_query_result, fn -> nil end)
      |> assign_new(:custom_visualization_spec, fn -> nil end)
      |> assign_new(:engagement_start_date, fn ->
        start_date =
          case assigns.section.start_date do
            nil -> Date.add(Date.utc_today(), -30) |> Date.to_string()
            start_date -> DateTime.to_date(start_date) |> Date.to_string()
          end

        start_date
      end)
      |> assign_new(:engagement_end_date, fn ->
        end_date =
          case assigns.section.end_date do
            nil -> Date.utc_today() |> Date.to_string()
            end_date -> DateTime.to_date(end_date) |> Date.to_string()
          end

        end_date
      end)
      |> assign_new(:engagement_max_pages, fn -> 25 end)
      |> assign_new(:resource_title_map, fn ->
        load_resource_title_map_from_section(assigns.section)
      end)

    {:ok, socket}
  end

  # Helper function to load the resource title map once when component loads
  defp load_resource_title_map_from_section(section) do
    hierarchy =
      Oli.Delivery.Sections.SectionResourceDepot.get_full_hierarchy(section, hidden: false)

    # Create a mapping from resource_id to title from the hierarchy
    extract_resource_titles_from_hierarchy(hierarchy)
  end

  # Public helper function to load resource title mapping for a section by ID
  def load_resource_title_map(section_id) when is_integer(section_id) do
    section = Oli.Delivery.Sections.get_section!(section_id)
    load_resource_title_map_from_section(section)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-2xl font-bold mb-6 text-gray-900 dark:text-white">
          Analytics Dashboard
        </h1>

        <%= case @section_analytics_load_state do %>
          <% :not_loaded -> %>
            <div class="bg-yellow-50 dark:bg-yellow-900 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4">
              <h3 class="text-md font-semibold text-yellow-900 dark:text-yellow-100 mb-2">
                Section analytics are not available yet
              </h3>
              <p class="text-sm text-yellow-800 dark:text-yellow-200">
                Historical analytics for this section have not been imported. Please contact a Torus administrator to request a ClickHouse backfill run.
              </p>
            </div>
          <% :loading -> %>
            <div class="flex items-center bg-gray-50 dark:bg-gray-900 border rounded-lg p-4">
              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mr-3"></div>
              <p class="text-sm text-gray-600 dark:text-gray-300">
                Loading section analytics. This page will refresh automatically when the data is ready.
              </p>
            </div>
          <% {:error, reason} -> %>
            <div class="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-800 rounded-lg p-4">
              <h3 class="text-md font-semibold text-red-800 dark:text-red-100 mb-2">
                Unable to load section analytics
              </h3>
              <p class="text-sm text-red-700 dark:text-red-200">
                {reason}
              </p>
              <p class="text-sm text-red-700 dark:text-red-200 mt-2">
                If this issue persists, please contact an administrator to review the ClickHouse backfill job.
              </p>
            </div>
          <% _ -> %>
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
                        (executed in {:erlang.float_to_binary(result.execution_time_ms / 1,
                          decimals: 2
                        )}ms)
                      </span>
                    <% end %>
                  </div>
                  <!-- Event Type Cards -->
                  <% summary_rows = comprehensive_summary_rows(result) %>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                    <%= for %{event_type: event_type, total_events: total_events, unique_users: unique_users, additional_info: additional} <- summary_rows do %>
                      <div class="bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
                        <div class="flex items-center justify-between mb-2">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300">
                            {humanize_event_type(event_type)}
                          </span>
                        </div>
                        <div>
                          <p class="text-2xl font-bold text-gray-900 dark:text-white">
                            {total_events}
                          </p>
                          <p class="text-sm text-gray-600 dark:text-gray-300">
                            events from {unique_users} users
                          </p>
                          <%= if additional not in [nil, "", "0"] do %>
                            <p class="text-xs text-blue-600 dark:text-blue-400 mt-1">
                              {format_additional_info(event_type, additional)}
                            </p>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% {:error, reason} -> %>
                  <div class="text-red-600 dark:text-red-400 mb-3 flex items-start">
                    <svg
                      class="w-4 h-4 mr-2 mt-0.5 flex-shrink-0"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
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
                    if(@selected_analytics_category == "video",
                      do: "border-green-500",
                      else: "border-transparent hover:border-green-300"
                    )
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
                    if(@selected_analytics_category == "assessment",
                      do: "border-blue-500",
                      else: "border-transparent hover:border-blue-300"
                    )
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
                    if(@selected_analytics_category == "engagement",
                      do: "border-purple-500",
                      else: "border-transparent hover:border-purple-300"
                    )
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
                    if(@selected_analytics_category == "performance",
                      do: "border-yellow-500",
                      else: "border-transparent hover:border-yellow-300"
                    )
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
                    if(@selected_analytics_category == "cross_event",
                      do: "border-pink-500",
                      else: "border-transparent hover:border-pink-300"
                    )
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
                    if(@selected_analytics_category == "custom",
                      do: "border-gray-500",
                      else: "border-transparent hover:border-gray-300"
                    )
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
                    <% "video" -> %>
                      Video Analytics Visualization
                    <% "assessment" -> %>
                      Assessment Analytics Visualization
                    <% "engagement" -> %>
                      Engagement Analytics Visualization
                    <% "performance" -> %>
                      Performance Analytics Visualization
                    <% "cross_event" -> %>
                      Cross-Event Analytics Visualization
                    <% "custom" -> %>
                      Custom Analytics Builder
                    <% _ -> %>
                      Analytics Visualization
                  <% end %>
                </h2>
                <!-- Engagement Analytics Controls -->
                <%= if @selected_analytics_category == "engagement" do %>
                  <div class="mb-6 bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                    <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">
                      Filter Data
                    </h4>
                    <form
                      phx-change="update_engagement_filters"
                      phx-target={@myself}
                      class="grid grid-cols-1 md:grid-cols-3 gap-4"
                    >
                      <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Start Date
                        </label>
                        <input
                          type="date"
                          name="start_date"
                          value={
                            @engagement_start_date ||
                              Date.add(Date.utc_today(), -30) |> Date.to_string()
                          }
                          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                          End Date
                        </label>
                        <input
                          type="date"
                          name="end_date"
                          value={@engagement_end_date || Date.utc_today() |> Date.to_string()}
                          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Max Pages
                        </label>
                        <select
                          name="max_pages"
                          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm"
                        >
                          <option value="10" selected={@engagement_max_pages == 10}>
                            Top 10 Pages
                          </option>
                          <option value="25" selected={@engagement_max_pages == 25}>
                            Top 25 Pages
                          </option>
                          <option value="50" selected={@engagement_max_pages == 50}>
                            Top 50 Pages
                          </option>
                          <option value="100" selected={@engagement_max_pages == 100}>
                            Top 100 Pages
                          </option>
                          <option value="all" selected={@engagement_max_pages == "all"}>
                            All Pages
                          </option>
                        </select>
                      </div>
                    </form>
                  </div>
                <% end %>
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
                      <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">
                        ClickHouse SQL Query
                      </h4>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                        Write a SQL query to fetch data from the analytics database.
                        Use
                        <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">
                          #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
                        </code>
                        as the table name.
                      </p>
                      <div class="bg-yellow-50 dark:bg-yellow-900 border border-yellow-200 dark:border-yellow-700 rounded-lg p-3 mb-3">
                        <p class="text-sm text-yellow-800 dark:text-yellow-200">
                          <strong>Required:</strong>
                          Your query must include
                          <code class="bg-yellow-100 dark:bg-yellow-800 px-1 rounded">
                            WHERE section_id = {@section.id}
                          </code>
                          to filter results to the current section.
                        </p>
                      </div>
                      <div class="mb-3">
                        <Monaco.editor
                          id="custom-sql-editor"
                          class="min-w-full max-w-full"
                          language="sql"
                          height="200px"
                          resizable={true}
                          default_value={@custom_sql_query || get_default_sql_query(@section.id)}
                          default_options={
                            %{
                              "readOnly" => false,
                              "selectOnLineNumbers" => true,
                              "minimap" => %{"enabled" => false},
                              "scrollBeyondLastLine" => false,
                              "wordWrap" => "on",
                              "lineNumbers" => "on",
                              "tabSize" => 2,
                              "insertSpaces" => true,
                              "automaticLayout" => true
                            }
                          }
                          set_options="monaco_editor_set_sql_options"
                          set_value="monaco_editor_set_sql_value"
                          get_value="monaco_editor_get_sql_value"
                          use_code_lenses={[]}
                          on_change="update_custom_sql_field"
                          target={@myself}
                        />
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
                        <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">
                          Query Results
                        </h4>
                        <%= case @custom_query_result do %>
                          <% {:ok, %{body: body, execution_time_ms: execution_time}} -> %>
                            <div class="text-green-600 dark:text-green-400 mb-3 text-sm">
                              ✓ Query executed successfully ({format_execution_time(execution_time)})
                            </div>
                            <pre class="bg-white dark:bg-gray-800 border rounded p-3 text-xs overflow-x-auto max-h-40"><%= body %></pre>
                          <% {:ok, %{body: body}} -> %>
                            <div class="text-green-600 dark:text-green-400 mb-3 text-sm">
                              ✓ Query executed successfully
                            </div>
                            <pre class="bg-white dark:bg-gray-800 border rounded p-3 text-xs overflow-x-auto max-h-40"><%= body %></pre>
                          <% {:error, reason} -> %>
                            <div class="text-red-600 dark:text-red-400 mb-3 text-sm">
                              ✗ Query failed
                            </div>
                            <pre class="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded p-3 text-xs text-red-800 dark:text-red-200"><%= reason %></pre>
                        <% end %>
                      </div>
                    <% end %>
                    <!-- VegaLite Spec Editor -->
                    <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                      <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">
                        VegaLite Visualization Spec
                      </h4>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                        Define a VegaLite specification to visualize your query results. The data will be automatically injected.
                      </p>
                      <div class="mb-3">
                        <Monaco.editor
                          id="custom-vega-editor"
                          class="min-w-full max-w-full"
                          language="json"
                          height="300px"
                          resizable={true}
                          default_value={@custom_vega_spec || get_default_vega_spec()}
                          default_options={
                            %{
                              "readOnly" => false,
                              "selectOnLineNumbers" => true,
                              "minimap" => %{"enabled" => false},
                              "scrollBeyondLastLine" => false,
                              "wordWrap" => "on",
                              "lineNumbers" => "on",
                              "tabSize" => 2,
                              "insertSpaces" => true,
                              "automaticLayout" => true,
                              "formatOnPaste" => true,
                              "formatOnType" => true
                            }
                          }
                          set_options="monaco_editor_set_vega_options"
                          set_value="monaco_editor_set_vega_value"
                          get_value="monaco_editor_get_vega_value"
                          use_code_lenses={[]}
                          on_change="update_custom_vega_field"
                          target={@myself}
                        />
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
                        <h4 class="text-md font-semibold mb-3 text-gray-900 dark:text-white text-center">
                          Custom Visualization
                        </h4>
                        <div class="flex justify-center items-center">
                          {{:safe, _chart_html} =
                            OliWeb.Common.React.component(
                              %{is_liveview: true},
                              "Components.VegaLiteRenderer",
                              %{spec: @custom_visualization_spec},
                              id: "custom-analytics-chart"
                            )}
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <!-- Regular Analytics Interface -->
                  <%= cond do %>
                    <% @analytics_spec == nil -> %>
                      <div class="flex items-center justify-center py-8">
                        <div class="text-center">
                          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4">
                          </div>
                          <p class="text-gray-500 dark:text-gray-400">Loading analytics data...</p>
                        </div>
                      </div>
                    <% is_list(@analytics_spec) && length(@analytics_spec) > 0 -> %>
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
                      <%= for {chart, index} <- Enum.with_index(@analytics_spec) do %>
                        <div class="mb-6">
                          <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                            <h4 class="text-sm font-medium mb-3 text-gray-700 dark:text-gray-300 text-center">
                              {chart.title}
                            </h4>
                            <div class="overflow-x-auto overflow-y-hidden" style="max-width: 100%;">
                              <div class="flex justify-center items-center min-w-max">
                                {{:safe, _chart_html} =
                                  OliWeb.Common.React.component(
                                    %{is_liveview: true},
                                    "Components.VegaLiteRenderer",
                                    %{spec: chart.spec},
                                    id: "analytics-chart-#{@selected_analytics_category}-#{index}"
                                  )}
                              </div>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    <% true -> %>
                      <div class="flex items-center justify-center py-12">
                        <div class="text-center">
                          <div class="mb-4">
                            <svg
                              class="mx-auto h-12 w-12 text-gray-400"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                              />
                            </svg>
                          </div>
                          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                            Not Enough Data
                          </h3>
                          <p class="text-gray-600 dark:text-gray-400">
                            There isn't enough data available to generate this visualization.
                            Try again once there's more student activity in your section.
                          </p>
                        </div>
                      </div>
                  <% end %>

                  <%= if @analytics_data && (
                (@selected_analytics_category == "engagement" && is_map(@analytics_data) &&
                  (length(Map.get(@analytics_data, :bar_chart_data, [])) > 0 || length(Map.get(@analytics_data, :heatmap_data, [])) > 0)) ||
                (@selected_analytics_category != "engagement" && is_list(@analytics_data) && length(@analytics_data) > 0)
              ) do %>
                    <div class="mt-6">
                      <h3 class="text-md font-semibold mb-3 text-gray-900 dark:text-white">
                        Raw Data Summary
                      </h3>
                      <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
                        <p class="text-sm text-gray-600 dark:text-gray-400 mb-2">
                          <%= if @selected_analytics_category == "engagement" do %>
                            Showing {length(Map.get(@analytics_data, :bar_chart_data, []))} page engagement records and {length(
                              Map.get(@analytics_data, :heatmap_data, [])
                            )} time-based activity records.
                          <% else %>
                            Showing {length(@analytics_data)} data points for this analysis.
                          <% end %>
                        </p>
                        <details class="text-sm">
                          <summary class="cursor-pointer text-blue-600 dark:text-blue-400 hover:underline">
                            View detailed data
                          </summary>
                          <div class="mt-2 p-3 bg-white dark:bg-gray-800 rounded border">
                            <Monaco.editor
                              id={"raw-data-#{@selected_analytics_category}"}
                              class="min-w-full max-w-full"
                              language="elixir"
                              height="300px"
                              resizable={true}
                              default_value={inspect(@analytics_data, pretty: true, limit: :infinity)}
                              default_options={
                                %{
                                  "readOnly" => true,
                                  "selectOnLineNumbers" => true,
                                  "minimap" => %{"enabled" => false},
                                  "scrollBeyondLastLine" => false,
                                  "wordWrap" => "on",
                                  "lineNumbers" => "on",
                                  "tabSize" => 2,
                                  "insertSpaces" => true,
                                  "automaticLayout" => true,
                                  "formatOnPaste" => true,
                                  "formatOnType" => true
                                }
                              }
                            />
                          </div>
                        </details>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
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
    socket =
      if category == "custom" do
        socket
        |> assign_new(:custom_sql_query, fn ->
          get_default_sql_query(socket.assigns.section.id)
        end)
        |> assign_new(:custom_vega_spec, fn -> get_default_vega_spec() end)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_custom_query", _params, socket) do
    # Get the current query from assigns, or use default if none exists
    query =
      case socket.assigns.custom_sql_query do
        nil -> get_default_sql_query(socket.assigns.section.id)
        "" -> get_default_sql_query(socket.assigns.section.id)
        existing_query -> existing_query
      end

    if query && String.trim(query) != "" do
      case Oli.Analytics.ClickhouseQueryValidator.validate_custom_query(
             query,
             :section_id,
             socket.assigns.section.id
           ) do
        :ok ->
          # Add JSONEachRow format for easier parsing in custom analytics
          formatted_query =
            if String.contains?(String.downcase(query), "format") do
              query
            else
              query <> " FORMAT JSONEachRow"
            end

          result =
            Oli.Analytics.ClickhouseAnalytics.execute_query(
              formatted_query,
              "custom analytics query"
            )

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
    spec_to_use =
      if vega_spec && String.trim(vega_spec) != "", do: vega_spec, else: get_default_vega_spec()

    case {query_result, spec_to_use} do
      {{:ok, %{body: body}}, spec} when is_binary(spec) and spec != "" ->
        case parse_query_result_and_create_spec(body, spec) do
          {:ok, final_spec} ->
            {:noreply,
             assign(socket, custom_visualization_spec: final_spec, custom_vega_spec: spec_to_use)}

          {:error, reason} ->
            {:noreply,
             assign(socket, custom_query_result: {:error, "Visualization error: #{reason}"})}
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
  def handle_event("update_custom_sql_field", sql_value, socket) when is_binary(sql_value) do
    # Handle Monaco Editor SQL changes - Monaco sends the value directly as a string
    {:noreply, assign(socket, :custom_sql_query, sql_value)}
  end

  @impl true
  def handle_event("update_custom_vega_field", vega_value, socket) when is_binary(vega_value) do
    # Handle Monaco Editor VegaLite JSON changes - Monaco sends the value directly as a string
    {:noreply, assign(socket, :custom_vega_spec, vega_value)}
  end

  @impl true
  def handle_event("update_custom_field", params, socket) do
    # Handle Monaco Editor SQL changes
    case params do
      %{"value" => sql_value} ->
        {:noreply, assign(socket, :custom_sql, sql_value)}

      %{"sql" => sql_value} ->
        {:noreply, assign(socket, :custom_sql, sql_value)}

      _ ->
        Logger.info("Unexpected params in update_custom_field: #{inspect(params)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_custom_vega_field", params, socket) do
    # Handle Monaco Editor VegaLite JSON changes
    case params do
      %{"value" => vega_value} ->
        {:noreply, assign(socket, :custom_vega_lite, vega_value)}

      %{"vega" => vega_value} ->
        {:noreply, assign(socket, :custom_vega_lite, vega_value)}

      _ ->
        Logger.info("Unexpected params in update_custom_vega_field: #{inspect(params)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_engagement_filters", params, socket) do
    # Handle max_pages value - can be integer or "all"
    max_pages_value =
      case Map.get(params, "max_pages", "25") do
        "all" -> "all"
        value -> String.to_integer(value)
      end

    socket =
      socket
      |> assign(
        :engagement_start_date,
        Map.get(params, "start_date", socket.assigns.engagement_start_date)
      )
      |> assign(
        :engagement_end_date,
        Map.get(params, "end_date", socket.assigns.engagement_end_date)
      )
      |> assign(:engagement_max_pages, max_pages_value)

    # Reload engagement analytics with new filters
    if socket.assigns.selected_analytics_category == "engagement" do
      %{
        engagement_start_date: start_date,
        engagement_end_date: end_date,
        engagement_max_pages: max_pages,
        section: section,
        resource_title_map: resource_title_map
      } = socket.assigns

      {data, charts} =
        get_engagement_analytics_with_filters(
          section.id,
          start_date,
          end_date,
          max_pages,
          resource_title_map
        )

      socket =
        socket
        |> assign(:analytics_data, data)
        |> assign(:analytics_spec, charts)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp comprehensive_summary_rows(%{parsed_body: %{"data" => data} = parsed_body})
       when is_list(data) do
    meta = Map.get(parsed_body, "meta", [])

    data
    |> Enum.map(fn
      row when is_map(row) ->
        build_summary_row(row)

      row when is_list(row) ->
        row
        |> build_row_from_meta(meta)
        |> build_summary_row()

      _ ->
        build_summary_row(%{})
    end)
    |> normalize_summary_rows()
  end

  defp comprehensive_summary_rows(%{parsed_body: data}) when is_list(data) do
    data
    |> Enum.map(&build_summary_row/1)
    |> normalize_summary_rows()
  end

  defp comprehensive_summary_rows(%{body: body}) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "event_type")))
    |> Enum.flat_map(fn line ->
      case String.split(line, "\t") do
        parts when length(parts) >= 6 ->
          [summary_row_from_parts(parts)]

        _ ->
          []
      end
    end)
    |> normalize_summary_rows()
  end

  defp comprehensive_summary_rows(_), do: []

  defp build_summary_row(row) when is_map(row) do
    %{
      event_type:
        fetch_row_value(row, [:event_type, "event_type"])
        |> to_string_or_unknown(),
      total_events:
        fetch_row_value(row, [:total_events, "total_events"])
        |> to_string_or_zero(),
      unique_users:
        fetch_row_value(row, [:unique_users, "unique_users"])
        |> to_string_or_zero(),
      additional_info:
        fetch_row_value(row, [:additional_info, "additional_info"])
        |> to_string_or_nil()
    }
  end

  defp build_summary_row(_),
    do: %{event_type: "unknown", total_events: "0", unique_users: "0", additional_info: nil}

  defp summary_row_from_parts(parts) do
    [event_type, total_events, unique_users, _earliest, _latest, additional] = Enum.take(parts, 6)

    %{
      event_type: event_type,
      total_events: total_events,
      unique_users: unique_users,
      additional_info: additional
    }
  end

  defp normalize_summary_rows(rows) when is_list(rows) do
    rows
    |> Enum.map(&sanitize_summary_row/1)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.update(acc, row.event_type, row, &merge_summary_rows(&1, row))
    end)
    |> Map.values()
    |> Enum.sort_by(&event_type_sort_key/1)
  end

  defp normalize_summary_rows(_), do: []

  defp sanitize_summary_row(row) when is_map(row) do
    %{
      event_type: canonical_event_type(Map.get(row, :event_type)),
      total_events: integer_to_string(Map.get(row, :total_events)),
      unique_users: integer_to_string(Map.get(row, :unique_users)),
      additional_info: sanitize_optional_string(Map.get(row, :additional_info))
    }
  end

  defp sanitize_summary_row(_),
    do: %{
      event_type: "unknown",
      total_events: "0",
      unique_users: "0",
      additional_info: nil
    }

  defp merge_summary_rows(existing, incoming) do
    %{
      event_type: existing.event_type,
      total_events: sum_numeric_strings(existing.total_events, incoming.total_events),
      unique_users: max_numeric_strings(existing.unique_users, incoming.unique_users),
      additional_info: pick_additional_info(existing.additional_info, incoming.additional_info)
    }
  end

  defp canonical_event_type(nil), do: "unknown"

  defp canonical_event_type(event_type) when is_atom(event_type) do
    event_type
    |> Atom.to_string()
    |> canonical_event_type()
  end

  defp canonical_event_type(event_type) when is_binary(event_type) do
    normalized = String.trim(event_type)
    Map.get(@legacy_event_type_map, normalized, normalized)
  end

  defp canonical_event_type(_), do: "unknown"

  defp integer_to_string(value) do
    value
    |> parse_integer()
    |> Integer.to_string()
  end

  defp sanitize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp sanitize_optional_string(_), do: nil

  defp sum_numeric_strings(a, b) do
    (parse_integer(a) + parse_integer(b))
    |> Integer.to_string()
  end

  defp max_numeric_strings(a, b) do
    max(parse_integer(a), parse_integer(b))
    |> Integer.to_string()
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_float(value) do
    value
    |> Float.round()
    |> trunc()
  end

  defp parse_integer(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        0

      true ->
        case Integer.parse(trimmed) do
          {int_val, _} ->
            int_val

          :error ->
            case Float.parse(trimmed) do
              {float_val, _} ->
                float_val
                |> Float.round()
                |> trunc()

              :error ->
                0
            end
        end
    end
  end

  defp parse_integer(_), do: 0

  defp pick_additional_info(existing, incoming) do
    cond do
      not blank?(existing) -> existing
      not blank?(incoming) -> incoming
      true -> nil
    end
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(nil), do: true
  defp blank?(_), do: false

  defp event_type_sort_key(%{event_type: event_type}) do
    order_index =
      case Enum.find_index(@summary_event_type_order, &(&1 == event_type)) do
        nil -> length(@summary_event_type_order)
        idx -> idx
      end

    {order_index, event_type}
  end

  defp build_row_from_meta(values, meta) when is_list(values) and is_list(meta) do
    Enum.zip(meta, values)
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{%{"name" => name}, value}, index}, acc ->
        key = name || "column_#{index}"
        Map.put(acc, key, value)

      {{_meta_entry, value}, index}, acc ->
        Map.put(acc, "column_#{index}", value)
    end)
  end

  defp build_row_from_meta(values, _meta) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, acc ->
      Map.put(acc, "column_#{index}", value)
    end)
  end

  defp build_row_from_meta(_values, _meta), do: %{}

  defp fetch_row_value(row, keys) when is_list(keys) do
    Enum.reduce_while(keys, nil, fn key, _acc ->
      case fetch_row_value(row, key) do
        nil -> {:cont, nil}
        value -> {:halt, value}
      end
    end)
  end

  defp fetch_row_value(row, key) when is_map(row) and is_atom(key) do
    Map.get(row, key) || Map.get(row, Atom.to_string(key))
  end

  defp fetch_row_value(row, key) when is_map(row) and is_binary(key) do
    Map.get(row, key) ||
      case safe_to_existing_atom(key) do
        {:ok, atom_key} -> Map.get(row, atom_key)
        :error -> nil
      end
  end

  defp fetch_row_value(_, _), do: nil

  defp safe_to_existing_atom(key) do
    try do
      {:ok, String.to_existing_atom(key)}
    rescue
      ArgumentError -> :error
    end
  end

  defp to_string_or_zero(value) when is_number(value), do: to_string(value)

  defp to_string_or_zero(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        "0"

      trimmed == "total_events" ->
        "0"

      trimmed == "unique_users" ->
        "0"

      true ->
        case Integer.parse(trimmed) do
          {int_val, _} ->
            Integer.to_string(int_val)

          :error ->
            case Float.parse(trimmed) do
              {float_val, _} ->
                float_val
                |> Float.round(2)
                |> :erlang.float_to_binary(decimals: 2)
                |> to_string()

              :error ->
                "0"
            end
        end
    end
  end

  defp to_string_or_zero(_), do: "0"

  defp to_string_or_unknown(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" or trimmed == "event_type" do
      "unknown"
    else
      trimmed
    end
  end

  defp to_string_or_unknown(value) when is_atom(value) do
    value |> Atom.to_string() |> to_string_or_unknown()
  end

  defp to_string_or_unknown(nil), do: "unknown"
  defp to_string_or_unknown(value), do: to_string(value)

  defp to_string_or_nil(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> nil
      trimmed == "additional_info" -> nil
      true -> trimmed
    end
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)

  defp get_default_sql_query(section_id) do
    """
    SELECT
      event_type,
      count(*) as total_events,
      uniq(user_id) as unique_users
    FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
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
      # Parse JSON data (JSONEachRow format - one JSON object per line)
      chart_data = parse_json_each_row_data(query_body)

      # Parse the VegaLite spec
      base_spec = Jason.decode!(vega_spec_string)

      # Inject the data into the spec
      final_spec = Map.put(base_spec, "data", %{"values" => chart_data})

      # Convert to VegaLite spec format
      vega_spec = VegaLite.from_json(Jason.encode!(final_spec)) |> VegaLite.to_spec()

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
        video_url,
        countIf(video_time IS NOT NULL) as plays,
        countIf(video_progress >= 0.8) as completions,
        if(plays > 0, completions / plays * 100, 0) as completion_rate,
        avg(video_progress) as avg_progress,
        uniq(user_id) as unique_viewers
      FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'video' AND video_url IS NOT NULL
      GROUP BY content_element_id, video_url
      HAVING plays >= 1
      ORDER BY plays DESC
      LIMIT 20
    """

    case execute_analytics_query_json(query, "video analytics") do
      {:ok, data, execution_time} ->
        if length(data) > 0 do
          spec = create_video_completion_chart(data)

          charts = [
            %{
              title: "Video Completion Analysis (#{format_execution_time(execution_time)})",
              spec: spec
            }
          ]

          {data, charts}
        else
          {[], []}
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
      FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type IN ('activity_attempt', 'page_attempt') AND activity_id IS NOT NULL
      GROUP BY activity_id
      HAVING total_attempts >= 1
      ORDER BY total_attempts DESC
      LIMIT 20
    """

    case execute_analytics_query_json(query, "assessment analytics") do
      {:ok, data, execution_time} ->
        if length(data) > 0 do
          spec = create_assessment_performance_chart(data)

          charts = [
            %{
              title: "Assessment Performance Analysis (#{format_execution_time(execution_time)})",
              spec: spec
            }
          ]

          {data, charts}
        else
          {[], []}
        end

      {:error, reason} ->
        Logger.error("Assessment analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  def get_analytics_data_and_spec("engagement", section_id) do
    # Use default filters if called without filters
    get_engagement_analytics_with_filters(section_id, nil, nil, 25)
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
      FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'part_attempt' AND scaled_score IS NOT NULL
      GROUP BY score_range
      ORDER BY score_range
    """

    case execute_analytics_query_json(query, "performance analytics") do
      {:ok, data, execution_time} ->
        if length(data) > 0 do
          spec = create_score_distribution_chart(data)

          charts = [
            %{
              title: "Score Distribution Analysis (#{format_execution_time(execution_time)})",
              spec: spec
            }
          ]

          {data, charts}
        else
          {[], []}
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
      FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
      WHERE section_id = #{section_id}
      GROUP BY event_type, month
      ORDER BY month DESC, event_type
      LIMIT 100
    """

    case execute_analytics_query_json(query, "cross-event analytics") do
      {:ok, data, execution_time} ->
        if length(data) > 0 do
          spec = create_event_timeline_chart(data)

          charts = [
            %{
              title: "Event Timeline Analysis (#{format_execution_time(execution_time)})",
              spec: spec
            }
          ]

          {data, charts}
        else
          {[], []}
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

  def get_analytics_data_and_spec("engagement", section_id, resource_title_map) do
    # Use default filters if called without filters, but with provided resource title map
    get_engagement_analytics_with_filters(section_id, nil, nil, 25, resource_title_map)
  end

  # Helper function to get analytics data with resource title map from component assigns
  def get_analytics_data_and_spec_with_resource_map(category, section_id, resource_title_map) do
    case category do
      "engagement" -> get_analytics_data_and_spec("engagement", section_id, resource_title_map)
      _ -> get_analytics_data_and_spec(category, section_id)
    end
  end

  # Helper function to get analytics data with filters and resource title map
  def get_analytics_data_and_spec_with_filters_and_resource_map(
        category,
        section_id,
        start_date,
        end_date,
        max_pages,
        resource_title_map
      ) do
    case category do
      "engagement" ->
        get_engagement_analytics_with_filters(
          section_id,
          start_date,
          end_date,
          max_pages,
          resource_title_map
        )

      _ ->
        get_analytics_data_and_spec(category, section_id)
    end
  end

  def get_engagement_analytics_with_filters(
        section_id,
        start_date,
        end_date,
        max_pages,
        resource_title_map \\ nil
      ) do
    # Use provided resource title map or load it if not provided
    resource_title_map =
      case resource_title_map do
        nil ->
          # Load the full hierarchy to get page titles
          section = Oli.Repo.get!(Oli.Delivery.Sections.Section, section_id)

          hierarchy =
            Oli.Delivery.Sections.SectionResourceDepot.get_full_hierarchy(section, hidden: false)

          # Create a mapping from resource_id to title from the hierarchy
          title_map = extract_resource_titles_from_hierarchy(hierarchy)

          title_map

        existing_map ->
          existing_map
      end

    # Build date filter condition
    date_filter =
      case {start_date, end_date} do
        {nil, nil} ->
          ""

        {start_date, nil} when is_binary(start_date) ->
          " AND toDate(timestamp) >= '#{start_date}'"

        {nil, end_date} when is_binary(end_date) ->
          " AND toDate(timestamp) <= '#{end_date}'"

        {start_date, end_date} when is_binary(start_date) and is_binary(end_date) ->
          " AND toDate(timestamp) >= '#{start_date}' AND toDate(timestamp) <= '#{end_date}'"

        _ ->
          ""
      end

    # Build limit clause based on max_pages setting
    limit_clause =
      case max_pages do
        "all" -> ""
        nil -> "LIMIT 25"
        pages when is_integer(pages) -> "LIMIT #{pages}"
        _ -> "LIMIT 25"
      end

    # Main engagement query for bar chart
    query = """
      SELECT
        page_id,
        page_sub_type,
        count(*) as total_views,
        uniq(user_id) as unique_viewers,
        countIf(completion = true) as completed_views,
        if(total_views > 0, completed_views / total_views * 100, 0) as completion_rate
      FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
      WHERE section_id = #{section_id} AND event_type = 'page_viewed' AND page_id IS NOT NULL#{date_filter}
      GROUP BY page_id, page_sub_type
      HAVING total_views >= 1
      ORDER BY total_views DESC
      #{limit_clause}
    """

    case execute_analytics_query_json(query, "engagement analytics") do
      {:ok, data, main_query_time} ->
        # Use a WITH clause (CTE) to get heatmap data for only the top pages
        # This is more reliable than the two-step approach
        heatmap_query = """
          WITH top_pages AS (
            SELECT page_id
            FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()}
            WHERE section_id = #{section_id} AND event_type = 'page_viewed' AND page_id IS NOT NULL#{date_filter}
            GROUP BY page_id
            HAVING count(*) >= 1
            ORDER BY count(*) DESC
            #{limit_clause}
          )
          SELECT
            h.page_id,
            toDate(h.timestamp) as date,
            count(*) as view_count
          FROM #{Oli.Analytics.ClickhouseAnalytics.raw_events_table()} h
          INNER JOIN top_pages tp ON h.page_id = tp.page_id
          WHERE h.section_id = #{section_id}
            AND h.event_type = 'page_viewed'
            AND h.page_id IS NOT NULL#{date_filter}
          GROUP BY h.page_id, date
          HAVING view_count >= 1
          ORDER BY view_count DESC, h.page_id, date
        """

        # Get heatmap data
        {heatmap_data, heatmap_query_time} =
          case execute_analytics_query_json(heatmap_query, "engagement heatmap") do
            {:ok, heatmap_data, heatmap_time} ->
              {heatmap_data, heatmap_time}

            {:error, reason} ->
              Logger.error("Heatmap query failed: #{inspect(reason)}")
              {[], 0}
          end

        if length(data) > 0 || length(heatmap_data) > 0 do
          # Replace page IDs with titles in both datasets
          enriched_bar_data = enrich_data_with_titles(data, resource_title_map)

          enriched_heatmap_data =
            enrich_heatmap_data_with_titles(heatmap_data, resource_title_map)

          bar_spec = create_page_engagement_chart(enriched_bar_data)

          heatmap_spec = create_engagement_heatmap_chart(enriched_heatmap_data)

          # Return both charts as a list
          combined_data = %{
            bar_chart_data: enriched_bar_data,
            heatmap_data: enriched_heatmap_data
          }

          charts = [
            %{
              title: "Page Engagement (#{format_execution_time(main_query_time)})",
              spec: bar_spec
            },
            %{
              title: "Activity Heatmap (#{format_execution_time(heatmap_query_time)})",
              spec: heatmap_spec
            }
          ]

          {combined_data, charts}
        else
          {%{bar_chart_data: [], heatmap_data: []}, []}
        end

      {:error, reason} ->
        Logger.error("Engagement analytics query failed: #{inspect(reason)}")
        {[], []}
    end
  end

  # Helper function to execute analytics queries with JSON format for easier parsing
  defp execute_analytics_query_json(query, description) do
    # Add JSON format to the query
    formatted_query =
      if String.contains?(String.downcase(query), "format") do
        query
      else
        query <> " FORMAT JSONEachRow"
      end

    case Oli.Analytics.ClickhouseAnalytics.execute_query(formatted_query, description) do
      {:ok, %{parsed_body: parsed, execution_time_ms: execution_time_ms}}
      when is_list(parsed) ->
        {:ok, parsed, execution_time_ms}

      {:ok, %{body: body, execution_time_ms: execution_time_ms}} ->
        {:ok, parse_json_each_row_data(body), execution_time_ms}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper function to format execution time for display
  defp format_execution_time(time_ms) when is_number(time_ms) do
    cond do
      time_ms < 1 -> "< 1ms"
      time_ms < 1000 -> "#{:erlang.float_to_binary(time_ms, decimals: 1)}ms"
      true -> "#{:erlang.float_to_binary(time_ms / 1000, decimals: 2)}s"
    end
  end

  defp format_execution_time(_), do: "unknown"

  defp parse_json_each_row_data(body) when is_binary(body) do
    lines = String.split(String.trim(body), "\n", trim: true)

    # Filter out separator lines and empty lines before parsing JSON
    filtered_lines =
      lines
      |> Enum.filter(fn line ->
        trimmed = String.trim(line)
        # Keep lines that start with { (JSON objects) and reject separator lines with just dashes
        String.starts_with?(trimmed, "{") && !String.match?(trimmed, ~r/^-+$/)
      end)

    result =
      filtered_lines
      |> Enum.map(fn line ->
        case Jason.decode(String.trim(line)) do
          {:ok, json_obj} ->
            json_obj

          {:error, error} ->
            Logger.warning("Failed to parse JSON line '#{line}': #{inspect(error)}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    result
  end

  # Chart creation functions...
  defp create_video_completion_chart(data) do
    chart_data =
      Enum.take(data, 10)
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        # Handle both JSON (map) and TSV (list) data formats
        {_id, url, plays, _completions, completion_rate, _avg_progress, _viewers} =
          case row do
            %{} = json_row ->
              # JSON format from JSONEachRow
              {
                Map.get(json_row, "content_element_id"),
                Map.get(json_row, "video_url"),
                Map.get(json_row, "plays"),
                Map.get(json_row, "completions"),
                Map.get(json_row, "completion_rate"),
                Map.get(json_row, "avg_progress"),
                Map.get(json_row, "unique_viewers")
              }

            list when is_list(list) ->
              # TSV format (array)
              case list do
                [id, t, p, c, cr, ap, v] -> {id, t, p, c, cr, ap, v}
                _ -> ["", "Unknown", "0", "0", "0", "0", "0"]
              end

            _ ->
              {"", "Unknown", "0", "0", "0", "0", "0"}
          end

        %{
          "video" => "Video #{idx + 1}",
          "title" => String.slice(url || "Unknown", 0, 64),
          "completion_rate" =>
            case completion_rate do
              rate when is_binary(rate) ->
                case Float.parse(rate) do
                  {float_val, _} -> float_val
                  :error -> 0.0
                end

              rate when is_number(rate) ->
                rate

              _ ->
                0.0
            end,
          "plays" =>
            case plays do
              p when is_binary(p) ->
                case Integer.parse(p) do
                  {int_val, _} -> int_val
                  :error -> 0
                end

              p when is_number(p) ->
                p

              _ ->
                0
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
            %{} = json_row ->
              # JSON format from JSONEachRow
              [
                Map.get(json_row, "activity_id"),
                Map.get(json_row, "total_attempts"),
                Map.get(json_row, "avg_score"),
                Map.get(json_row, "successful_attempts"),
                Map.get(json_row, "unique_users")
              ]

            list when is_list(list) ->
              list

            _ ->
              ["", "0", "0", "0", "0"]
          end

        attempts_num =
          case attempts do
            a when is_binary(a) ->
              case Integer.parse(a) do
                {int_val, _} -> int_val
                :error -> 0
              end

            a when is_number(a) ->
              a

            _ ->
              0
          end

        avg_score_num =
          case avg_score do
            s when is_binary(s) ->
              case Float.parse(s) do
                {float_val, _} -> float_val * 100
                :error -> 0.0
              end

            s when is_number(s) ->
              s * 100

            _ ->
              0.0
          end

        successful_num =
          case successful do
            s when is_binary(s) ->
              case Integer.parse(s) do
                {int_val, _} -> int_val
                :error -> 0
              end

            s when is_number(s) ->
              s

            _ ->
              0
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
      data
      |> Enum.with_index()
      |> Enum.map(fn {row, _idx} ->
        # Handle both JSON (map) and TSV (list) data formats
        {page_id, page_type, views, viewers, _completed, completion_rate, title} =
          case row do
            %{} = json_row ->
              # JSON format from JSONEachRow
              {
                Map.get(json_row, "page_id"),
                Map.get(json_row, "page_sub_type"),
                Map.get(json_row, "total_views"),
                Map.get(json_row, "unique_viewers"),
                Map.get(json_row, "completed_views"),
                Map.get(json_row, "completion_rate"),
                Map.get(json_row, "page_title")
              }

            list when is_list(list) ->
              # TSV format (array)
              case list do
                [p_id, p_type, views, viewers, completed, rate, page_title] ->
                  {p_id, p_type, views, viewers, completed, rate, page_title}

                [p_id, p_type, views, viewers, completed, rate] ->
                  {p_id, p_type, views, viewers, completed, rate, "Page #{p_id}"}

                _ ->
                  {"", "Unknown", "0", "0", "0", "0", "Unknown"}
              end

            _ ->
              {"", "Unknown", "0", "0", "0", "0", "Unknown"}
          end

        views_num =
          case views do
            v when is_binary(v) ->
              case Integer.parse(v) do
                {int_val, _} -> int_val
                :error -> 0
              end

            v when is_number(v) ->
              v

            _ ->
              0
          end

        viewers_num =
          case viewers do
            v when is_binary(v) ->
              case Integer.parse(v) do
                {int_val, _} -> int_val
                :error -> 0
              end

            v when is_number(v) ->
              v

            _ ->
              0
          end

        completion_rate_num =
          case completion_rate do
            r when is_binary(r) ->
              case Float.parse(r) do
                {float_val, _} -> float_val
                :error -> 0.0
              end

            r when is_number(r) ->
              r

            _ ->
              0.0
          end

        # Truncate title for display but keep full title for tooltip
        display_title =
          if String.length(title || "Unknown") > 25 do
            String.slice(title, 0, 22) <> "..."
          else
            title || "Unknown"
          end

        %{
          "page" => display_title,
          "page_id" => page_id || "Unknown",
          "page_type" => page_type || "Unknown",
          "page_title" => title || "Unknown",
          "views" => views_num,
          "unique_viewers" => viewers_num,
          "completion_rate" => completion_rate_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    # Calculate dynamic width based on number of items, with minimum bar width
    num_items = length(chart_data)
    min_bar_width = 40
    chart_width = max(600, num_items * min_bar_width)

    VegaLite.from_json("""
    {
      "width": #{chart_width},
      "height": 400,
      "title": "Page Engagement Metrics",
      "description": "Page view counts and completion rates (scroll horizontally for more data)",
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
          "title": "Page Titles",
          "axis": {
            "labelAngle": -45,
            "labelLimit": 120
          },
          "scale": {
            "type": "band",
            "paddingInner": 0.1,
            "paddingOuter": 0.05
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
        },
        "tooltip": [
          {"field": "page_title", "type": "nominal", "title": "Page Title"},
          {"field": "views", "type": "quantitative", "title": "Total Views"},
          {"field": "unique_viewers", "type": "quantitative", "title": "Unique Viewers"},
          {"field": "completion_rate", "type": "quantitative", "title": "Completion Rate (%)"},
          {"field": "page_type", "type": "nominal", "title": "Page Type"}
        ]
      },
      "config": {
        "view": {
          "stroke": "transparent"
        },
        "axis": {
          "grid": false,
          "domain": false
        }
      }
    }
    """)
    |> VegaLite.to_spec()
  end

  defp create_engagement_heatmap_chart(data) do
    # Limit data size to prevent browser crashes with too much data
    limited_data = Enum.take(data, 500)

    chart_data =
      Enum.map(limited_data, fn row ->
        # Handle both JSON (map) and TSV (list) data formats
        {page_id, date, total_views, title} =
          case row do
            %{} = json_row ->
              # JSON format from JSONEachRow
              {
                Map.get(json_row, "page_id"),
                Map.get(json_row, "date"),
                Map.get(json_row, "view_count"),
                Map.get(json_row, "page_title")
              }

            list when is_list(list) ->
              # TSV format (array)
              case list do
                [p_id, d, views, page_title] -> {p_id, d, views, page_title}
                [p_id, d, views] -> {p_id, d, views, "Page #{p_id}"}
                _ -> ["unknown", "2024-01-01", "0", "Unknown"]
              end

            _ ->
              {"unknown", "2024-01-01", "0", "Unknown"}
          end

        views_num =
          case total_views do
            v when is_binary(v) ->
              case Integer.parse(v) do
                {int_val, _} -> int_val
                :error -> 0
              end

            v when is_number(v) ->
              v

            _ ->
              0
          end

        # Truncate title for display
        display_title =
          if String.length(title || "Unknown") > 20 do
            String.slice(title, 0, 17) <> "..."
          else
            title || "Unknown"
          end

        %{
          "page_id" => page_id || "unknown",
          "page_title" => title || "Unknown",
          "page_display" => display_title,
          "date" => date || "2024-01-01",
          "total_views" => views_num
        }
      end)

    encoded_data = Jason.encode!(chart_data)

    # Calculate dynamic dimensions based on data
    unique_dates = chart_data |> Enum.map(& &1["date"]) |> Enum.uniq() |> length()
    unique_pages = chart_data |> Enum.map(& &1["page_display"]) |> Enum.uniq() |> length()

    cell_width = 40
    cell_height = 25
    chart_width = max(600, unique_dates * cell_width)
    chart_height = max(300, unique_pages * cell_height)

    VegaLite.from_json("""
    {
      "width": #{chart_width},
      "height": #{chart_height},
      "title": "Page Views Heatmap by Date",
      "description": "Heatmap showing page view intensity by page and date (scroll to explore)",
      "data": {
        "values": #{encoded_data}
      },
      "mark": {
        "type": "rect",
        "tooltip": true,
        "stroke": "white",
        "strokeWidth": 0
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
          "field": "page_display",
          "type": "ordinal",
          "title": "Page Title",
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
        },
        "tooltip": [
          {"field": "page_title", "type": "nominal", "title": "Page Title"},
          {"field": "date", "type": "ordinal", "title": "Date"},
          {"field": "total_views", "type": "quantitative", "title": "Total Views"}
        ]
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
            %{} = json_row ->
              # JSON format from JSONEachRow
              [
                Map.get(json_row, "score_range"),
                Map.get(json_row, "attempt_count"),
                Map.get(json_row, "avg_hints")
              ]

            list when is_list(list) ->
              list

            _ ->
              ["Unknown", "0", "0"]
          end

        count_num =
          case count do
            c when is_binary(c) ->
              case Integer.parse(c) do
                {int_val, _} -> int_val
                :error -> 0
              end

            c when is_number(c) ->
              c

            _ ->
              0
          end

        hints_num =
          case avg_hints do
            h when is_binary(h) ->
              case Float.parse(h) do
                {float_val, _} -> float_val
                :error -> 0.0
              end

            h when is_number(h) ->
              h

            _ ->
              0.0
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
            %{} = json_row ->
              # JSON format from JSONEachRow
              [
                Map.get(json_row, "event_type"),
                Map.get(json_row, "total_events"),
                Map.get(json_row, "unique_users"),
                Map.get(json_row, "month")
              ]

            list when is_list(list) ->
              list

            _ ->
              ["unknown", "0", "0", "202401"]
          end

        month_str =
          case month do
            m when is_integer(m) -> Integer.to_string(m)
            m when is_binary(m) -> m
            _ -> "202401"
          end

        year = String.slice(month_str, 0, 4)
        month_num = String.slice(month_str, 4, 2)

        count_num =
          case count do
            c when is_binary(c) ->
              case Integer.parse(c) do
                {int_val, _} -> int_val
                :error -> 0
              end

            c when is_number(c) ->
              c

            _ ->
              0
          end

        users_num =
          case users do
            u when is_binary(u) ->
              case Integer.parse(u) do
                {int_val, _} -> int_val
                :error -> 0
              end

            u when is_number(u) ->
              u

            _ ->
              0
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

  # Helper function to recursively extract resource titles from hierarchy
  defp extract_resource_titles_from_hierarchy(hierarchy) do
    extract_titles_recursive(hierarchy, %{})
  end

  defp extract_titles_recursive(%{"children" => children} = node, acc) when is_list(children) do
    # Extract title from current node if it has resource_id and title
    acc =
      case {Map.get(node, "resource_id"), Map.get(node, "title")} do
        {resource_id, title} when not is_nil(resource_id) and not is_nil(title) ->
          Map.put(acc, to_string(resource_id), title)

        _ ->
          acc
      end

    # Recursively process children
    Enum.reduce(children, acc, &extract_titles_recursive/2)
  end

  defp extract_titles_recursive(%{"resource_id" => resource_id, "title" => title}, acc)
       when not is_nil(resource_id) and not is_nil(title) do
    Map.put(acc, to_string(resource_id), title)
  end

  # Handle the case where the hierarchy root might be a list of nodes
  defp extract_titles_recursive(nodes, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, &extract_titles_recursive/2)
  end

  defp extract_titles_recursive(_, acc), do: acc

  # Helper function to enrich bar chart data with titles
  defp enrich_data_with_titles(data, resource_title_map) do
    enriched =
      Enum.map(data, fn row ->
        case row do
          %{} = json_row ->
            # JSON format - add title field
            page_id = Map.get(json_row, "page_id")
            title = Map.get(resource_title_map, to_string(page_id), "Page #{page_id}")
            Map.put(json_row, "page_title", title)

          list when is_list(list) ->
            # TSV format - append title to the list
            case list do
              [page_id | rest] ->
                title = Map.get(resource_title_map, to_string(page_id), "Page #{page_id}")
                [page_id | rest] ++ [title]

              _ ->
                list ++ ["Unknown Title"]
            end

          _ ->
            row
        end
      end)

    enriched
  end

  # Helper function to enrich heatmap data with titles
  defp enrich_heatmap_data_with_titles(data, resource_title_map) do
    enriched =
      Enum.map(data, fn row ->
        case row do
          %{} = json_row ->
            # JSON format - add title field
            page_id = Map.get(json_row, "page_id")
            title = Map.get(resource_title_map, to_string(page_id), "Page #{page_id}")
            Map.put(json_row, "page_title", title)

          list when is_list(list) ->
            # TSV format - append title to the list
            case list do
              [page_id, date, count] ->
                title = Map.get(resource_title_map, to_string(page_id), "Page #{page_id}")
                [page_id, date, count, title]

              _ ->
                list ++ ["Unknown Title"]
            end

          _ ->
            row
        end
      end)

    enriched
  end
end
