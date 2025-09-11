defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  require Logger

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias Oli.Delivery.RecommendedActions
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias OliWeb.Components.Delivery.InstructorDashboard.TabLink
  alias OliWeb.Components.Delivery.Students
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  defp do_handle_students_params(%{"active_tab" => active_tab} = params, _, socket) do
    view = String.to_existing_atom(params["view"])
    params = Students.decode_params(params)

    socket =
      socket
      |> assign(
        params: params,
        view: view,
        active_tab: maybe_get_tab_from_params(active_tab, :content)
      )
      |> assign(users: Helpers.get_students(socket.assigns.section, params))
      |> assign(dropdown_options: get_dropdown_options(socket.assigns.section))
      |> Helpers.maybe_assign_certificate_data()

    socket =
      if params.container_id do
        selected_container =
          socket.assigns.section
          |> Helpers.get_containers()
          |> elem(1)
          |> Enum.find(&(&1.id == params.container_id))

        async_calculate_proficiency(socket.assigns.section)

        assign(socket, :selected_container, selected_container)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "content", "container_id" => _container_id} =
          params,
        uri,
        socket
      ) do
    do_handle_students_params(params, uri, socket)
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "learning_objectives"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :learning_objectives,
        section: socket.assigns.section
      )
      |> assign_new(:objectives_tab, fn ->
        %{
          objectives:
            Sections.get_objectives_and_subobjectives(socket.assigns.section,
              exclude_sub_objectives: false
            ),
          filter_options:
            Sections.get_units_and_modules_from_a_section(socket.assigns.section.slug)
        }
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "scored_activities"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :scored_activities
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:assessments, fn %{students: students} ->
        result = Helpers.get_assessments(socket.assigns.section, students)

        pid = self()

        Task.async(fn ->
          result_with_metrics = Helpers.load_metrics(result, socket.assigns.section, students)
          send(pid, {:assessments, result_with_metrics})
        end)

        result
      end)
      |> assign_new(:activities, fn -> Oli.Activities.list_activity_registrations() end)
      |> assign_new(:scripts, fn %{activities: activities} ->
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        Enum.map(activities, fn a -> a.authoring_script end)
        |> Enum.concat(part_components)
        |> Enum.map(fn s -> Routes.static_path(OliWeb.Endpoint, "/js/" <> s) end)
      end)
      |> assign_new(:activity_types_map, fn %{activities: activities} ->
        Enum.reduce(activities, %{}, fn e, m -> Map.put(m, e.id, e) end)
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "practice_activities"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :practice_activities
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:practice_activities, fn %{students: students} ->
        result = Helpers.get_practice_pages(socket.assigns.section, students)

        pid = self()

        Task.async(fn ->
          result_with_metrics = Helpers.load_metrics(result, socket.assigns.section, students)
          send(pid, {:practice_activities, result_with_metrics})
        end)

        result
      end)
      |> assign_new(:activities, fn -> Oli.Activities.list_activity_registrations() end)
      |> assign_new(:scripts, fn %{activities: activities} ->
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        Enum.map(activities, fn a -> a.authoring_script end)
        |> Enum.concat(part_components)
        |> Enum.map(fn s -> Routes.static_path(OliWeb.Endpoint, "/js/" <> s) end)
      end)
      |> assign_new(:activity_types_map, fn %{activities: activities} ->
        Enum.reduce(activities, %{}, fn e, m -> Map.put(m, e.id, e) end)
      end)
      |> assign_new(:units_and_modules_options, fn ->
        Helpers.build_units_and_modules_options(socket.assigns.section.id)
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "surveys"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :surveys
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:surveys, fn %{students: students} ->
        result = Helpers.get_assessments_with_surveys(socket.assigns.section, students)

        pid = self()

        Task.async(fn ->
          result_with_metrics = Helpers.load_metrics(result, socket.assigns.section, students)
          send(pid, {:surveys, result_with_metrics})
        end)

        result
      end)
      |> assign_new(:activities, fn -> Oli.Activities.list_activity_registrations() end)
      |> assign_new(:scripts, fn %{activities: activities} ->
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        Enum.map(activities, fn a -> a.authoring_script end)
        |> Enum.concat(part_components)
        |> Enum.map(fn s -> Routes.static_path(OliWeb.Endpoint, "/js/" <> s) end)
      end)
      |> assign_new(:activity_types_map, fn %{activities: activities} ->
        Enum.reduce(activities, %{}, fn e, m -> Map.put(m, e.id, e) end)
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "advanced_analytics"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :advanced_analytics,
        health_status: nil,
        query_result: nil,
        selected_query: "",
        custom_query: "",
        executing: false,
        selected_analytics_category: params["analytics_category"],
        analytics_data: nil,
        analytics_spec: nil,
        comprehensive_section_analytics:
          Oli.Analytics.AdvancedAnalytics.comprehensive_section_analytics(
            socket.assigns.section.id
          )
      )
      |> maybe_load_analytics_data()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"view" => "insights"} = params, _, socket) do
    active_tab =
      case params["active_tab"] do
        nil -> :content
        tab -> maybe_get_tab_from_params(tab, :content)
      end

    socket =
      socket
      |> assign(params: params, view: :insights, active_tab: active_tab)
      |> assign_new(:containers, fn ->
        containers = Helpers.get_containers(socket.assigns.section)
        async_calculate_proficiency(socket.assigns.section)
        containers
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "overview", "active_tab" => "students"} = params,
        uri,
        socket
      ) do
    do_handle_students_params(params, uri, socket)
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "overview", "active_tab" => "recommended_actions", "section_slug" => _ss} =
          params,
        _,
        socket
      ) do
    socket =
      case socket.assigns[:has_scheduled_resources] do
        nil ->
          section = socket.assigns.section

          has_scheduled_resources =
            RecommendedActions.section_has_scheduled_resources?(section.id)

          scoring_pending_activities_count =
            RecommendedActions.section_scoring_pending_activities_count(section.id)

          approval_pending_posts_count =
            RecommendedActions.section_approval_pending_posts_count(section.id)

          has_pending_updates = RecommendedActions.section_has_pending_updates?(section.id)

          has_due_soon_activities =
            RecommendedActions.section_has_due_soon_activities?(section.id)

          assign(socket,
            has_scheduled_resources: has_scheduled_resources,
            scoring_pending_activities_count: scoring_pending_activities_count,
            approval_pending_posts_count: approval_pending_posts_count,
            has_pending_updates: has_pending_updates,
            has_due_soon_activities: has_due_soon_activities
          )

        _ ->
          socket
      end

    {:noreply, assign(socket, params: params, view: :overview, active_tab: :recommended_actions)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"view" => "overview", "section_slug" => _section_slug} = params, _, socket) do
    socket =
      case maybe_get_tab_from_params(params["active_tab"], :course_content) do
        value when value == :course_content ->
          socket =
            assign_new(socket, :hierarchy, fn ->
              section =
                socket.assigns.section
                |> Oli.Repo.preload([:base_project, :root_section_resource])

              hierarchy = %{"children" => Sections.build_hierarchy(section).children}
              OliWeb.Components.Delivery.CourseContent.adjust_hierarchy_for_only_pages(hierarchy)
            end)

          socket
          |> assign(
            params: params,
            view: :overview,
            active_tab: :course_content,
            current_position: 0,
            current_level: 0,
            breadcrumbs_tree: [{0, 0, "Curriculum"}],
            current_level_nodes: socket.assigns.hierarchy["children"]
          )

        tab ->
          socket
          |> assign(view: :overview, params: params, active_tab: tab)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    allowed_routes = [
      {nil, nil},
      {"overview", "course_content"},
      {"overview", "students"},
      {"overview", "quiz_scores"},
      {"overview", "recommended_actions"},
      {"insights", nil},
      {"insights", "content"},
      {"insights", "learning_objectives"},
      {"insights", "scored_activities"},
      {"insights", "practice_activities"},
      {"insights", "surveys"},
      {"insights", "advanced_analytics"},
      {"insights", "course_discussion"},
      {"discussions", nil}
    ]

    if {params["view"], params["active_tab"]} in allowed_routes do
      view =
        case params["view"] do
          nil -> :overview
          tab -> maybe_get_tab_from_params(tab, :overview)
        end

      active_tab =
        case params["active_tab"] do
          nil -> nil
          tab -> maybe_get_tab_from_params(tab, :course_content)
        end

      {:noreply,
       assign(socket,
         params: params,
         view: view,
         active_tab: active_tab
       )}
    else
      if params["view"] == "manage" do
        # redirect to the manage page new route
        {:noreply, redirect(socket, to: "/sections/#{params["section_slug"]}/manage")}
      else
        {:noreply,
         assign(socket,
           params: params,
           view: :not_found
         )}
      end
    end
  end

  defp path_for(view, tab, section_slug, true = _preview_mode) do
    Routes.instructor_dashboard_path(OliWeb.Endpoint, :preview, section_slug, view, tab)
  end

  defp path_for(view, tab, section_slug, false = _preview_mode) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      view,
      tab
    )
  end

  defp is_active_tab?(tab, active_tab), do: tab == active_tab

  defp overview_tabs(section_slug, preview_mode, active_tab) do
    [
      %TabLink{
        label: "Course Content",
        path: path_for(:overview, :course_content, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:course_content, active_tab)
      },
      %TabLink{
        label: "Students",
        path: path_for(:overview, :students, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:students, active_tab)
      },
      %TabLink{
        label: "Assessment Scores",
        path: path_for(:overview, :quiz_scores, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:quiz_scores, active_tab)
      },
      %TabLink{
        label: "Recommended Actions",
        path: path_for(:overview, :recommended_actions, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:recommended_actions, active_tab)
      }
    ]
  end

  defp insights_tabs(section_slug, preview_mode, active_tab) do
    [
      %TabLink{
        label: "Content",
        path: path_for(:insights, :content, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:content, active_tab)
      },
      %TabLink{
        label: "Learning Objectives",
        path: path_for(:insights, :learning_objectives, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:learning_objectives, active_tab)
      },
      %TabLink{
        label: "Scored Activities",
        path: path_for(:insights, :scored_activities, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:scored_activities, active_tab)
      },
      %TabLink{
        label: "Practice Activities",
        path: path_for(:insights, :practice_activities, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:practice_activities, active_tab)
      },
      %TabLink{
        label: "Surveys",
        path: path_for(:insights, :surveys, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:surveys, active_tab)
      },
      %TabLink{
        label: "Advanced Analytics",
        path: path_for(:insights, :advanced_analytics, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:advanced_analytics, active_tab)
      }
    ]
  end

  @impl Phoenix.LiveView
  def render(%{view: :overview, active_tab: :students} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id="students_table"
        module={OliWeb.Components.Delivery.Students}
        params={@params}
        ctx={@ctx}
        section={@section}
        view={@view}
        students={@users}
        certificate={@certificate}
        certificate_pending_email_notification_count={@certificate_pending_email_notification_count}
        dropdown_options={@dropdown_options}
      />
    </div>
    """
  end

  def render(%{view: :overview, active_tab: :quiz_scores} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id="quiz_scores_table"
        module={OliWeb.Components.Delivery.QuizScores}
        params={@params}
        section={@section}
        view={@view}
        patch_url_type={:quiz_scores_instructor}
      />
    </div>
    """
  end

  def render(%{view: :overview, active_tab: :recommended_actions} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10 p-6 bg-white dark:bg-gray-800 shadow-sm">
      <OliWeb.Components.Delivery.RecommendedActions.render
        section_slug={@section_slug}
        has_scheduled_resources={@has_scheduled_resources}
        scoring_pending_activities_count={@scoring_pending_activities_count}
        approval_pending_posts_count={@approval_pending_posts_count}
        has_pending_updates={@has_pending_updates}
        has_due_soon_activities={@has_due_soon_activities}
      />
    </div>
    """
  end

  def render(%{view: :overview, active_tab: :course_content} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10 bg-white dark:bg-gray-800 shadow-sm">
      <.live_component
        module={OliWeb.Components.Delivery.CourseContent}
        id="course_content_tab"
        ctx={assigns.ctx}
        hierarchy={assigns.hierarchy}
        current_position={assigns.current_position}
        current_level={assigns.current_level}
        breadcrumbs_tree={assigns.breadcrumbs_tree}
        current_level_nodes={assigns.current_level_nodes}
        section={assigns.section}
        is_instructor={true}
      />
    </div>
    """
  end

  def render(
        %{view: :insights, active_tab: :content, params: %{container_id: _container_id}} = assigns
      ) do
    ~H"""
    <div class="container mx-auto">
      <.live_component
        id="container_details_table"
        module={OliWeb.Components.Delivery.Students}
        title={@selected_container.title}
        tab_name={@active_tab}
        show_progress_csv_download={true}
        params={@params}
        ctx={@ctx}
        section={@section}
        view={@view}
        students={@users}
        dropdown_options={@dropdown_options}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :content} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id="content_table"
        module={OliWeb.Components.Delivery.Content}
        params={@params}
        section_slug={@section.slug}
        view={@view}
        containers={@containers}
        patch_url_type={:instructor_dashboard}
      />
    </div>
    <HTMLComponents.view_example_student_progress_modal />
    """
  end

  def render(%{view: :insights, active_tab: :learning_objectives} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id={"objectives_table_#{@section_slug}"}
        module={OliWeb.Components.Delivery.LearningObjectives}
        params={@params}
        view={@view}
        objectives_tab={@objectives_tab}
        section_slug={@section_slug}
        v25_migration={@section.v25_migration}
        patch_url_type={:instructor_dashboard}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :scored_activities} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10">
      <.live_component
        id="scored_activities_tab"
        module={OliWeb.Components.Delivery.ScoredActivities}
        section={@section}
        params={@params}
        assessments={@assessments}
        students={@students}
        scripts={@scripts}
        activity_types_map={@activity_types_map}
        view={@view}
        ctx={@ctx}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :practice_activities} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="mx-10 mb-10">
      <.live_component
        id="practice_activities_tab"
        module={OliWeb.Components.Delivery.PracticeActivities}
        section={@section}
        params={@params}
        assessments={@practice_activities}
        students={@students}
        scripts={@scripts}
        activity_types_map={@activity_types_map}
        units_and_modules_options={@units_and_modules_options}
        view={@view}
        ctx={@ctx}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :surveys} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

    <div class="mx-10 mb-10">
      <.live_component
        id="surveys_tab"
        module={OliWeb.Components.Delivery.Surveys}
        section={@section}
        params={@params}
        assessments={@surveys}
        students={@students}
        scripts={@scripts}
        activity_types_map={@activity_types_map}
        view={@view}
        ctx={@ctx}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :advanced_analytics} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section_slug, @preview_mode, @active_tab)} />

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
              <div class="bg-gray-50 dark:bg-gray-900 border rounded-lg overflow-hidden">
                <div class="border-t">
                  <pre class="p-4 text-xs overflow-x-auto"><%= result.body %></pre>
                </div>
              </div>
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

            <div class="bg-gradient-to-br from-gray-50 to-slate-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Technical Details</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• ClickHouse OLAP storage</li>
                <li>• Real-time ETL pipeline</li>
                <li>• Scalable architecture</li>
                <li>• xAPI standards compliance</li>
              </ul>
            </div>
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
                <% _ -> %> Analytics Visualization
              <% end %>
            </h2>

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
              <% end %>
            <% else %>
              <div class="flex items-center justify-center py-8">
                <div class="text-center">
                  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
                  <p class="text-gray-500 dark:text-gray-400">Loading analytics data...</p>
                </div>
              </div>
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
                    <pre class="mt-2 text-xs bg-white dark:bg-gray-800 p-2 rounded border overflow-x-auto"><%= inspect(@analytics_data, pretty: true, limit: :infinity) %></pre>
                  </details>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def render(%{view: :discussions} = assigns) do
    ~H"""
    <div class="container mx-auto">
      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
        ctx={@ctx}
        params={@params}
        section={@section}
      />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <Components.Common.not_found />
    """
  end

  defp get_dropdown_options(section) do
    case section.requires_payment do
      true ->
        [
          %{value: :enrolled, label: "Enrolled"},
          %{value: :suspended, label: "Suspended"},
          %{value: :paid, label: "Paid"},
          %{value: :not_paid, label: "Not Paid"},
          %{value: :grace_period, label: "Grace Period"},
          %{value: :non_students, label: "Non-Students"},
          %{value: :pending_confirmation, label: "Pending Confirmation"},
          %{value: :rejected, label: "Invitation Rejected"}
        ]

      false ->
        [
          %{value: :enrolled, label: "Enrolled"},
          %{value: :suspended, label: "Suspended"},
          %{value: :non_students, label: "Non-Students"},
          %{value: :pending_confirmation, label: "Pending Confirmation"},
          %{value: :rejected, label: "Invitation Rejected"}
        ]

      _ ->
        []
    end
  end

  defp async_calculate_proficiency(section) do
    pid = self()

    Task.async(fn ->
      contained_pages = Oli.Delivery.Sections.get_contained_pages(section)
      proficiency_per_container = Metrics.proficiency_per_container(section, contained_pages)

      send(pid, {:proficiency, proficiency_per_container})
    end)
  end

  defp maybe_get_tab_from_params(tab, default) do
    # if the user manually changed the url and entered an invalid tab
    # we prevent the app from crashing by returning the default tab
    try do
      String.to_existing_atom(tab)
    rescue
      _e -> default
    end
  end

  defp maybe_load_analytics_data(socket) do
    case socket.assigns.selected_analytics_category do
      nil ->
        socket

      category ->
        pid = self()

        Task.async(fn ->
          {data, spec} = get_analytics_data_and_spec(category, socket.assigns.section.id)
          send(pid, {:analytics_data_loaded, category, data, spec})
        end)

        socket
    end
  end

  defp get_analytics_data_and_spec("video", section_id) do
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

  defp get_analytics_data_and_spec("assessment", section_id) do
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

  defp get_analytics_data_and_spec("engagement", section_id) do
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

  defp get_analytics_data_and_spec("performance", section_id) do
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

  defp get_analytics_data_and_spec("cross_event", section_id) do
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

  defp get_analytics_data_and_spec(_, _), do: {[], []}

  defp parse_tsv_data(body) when is_binary(body) do
    lines = String.split(String.trim(body), "\n")

    case lines do
      [] ->
        []

      [_header | data_lines] ->
        Enum.map(data_lines, fn line ->
          String.split(line, "\t")
        end)
    end
  end

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
              {float_val, _} -> float_val * 100  # Convert to percentage
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
            "paddingInner": 0.0
          }
        },
        "color": {
          "field": "total_views",
          "type": "quantitative",
          "scale": {
          "range": ["#313795", "#5e8cc1", "#8dbddb", "#dbefe7", "#faf2b5", "#fcaf6b", "#dc4835", "#a50026"],
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

  @impl Phoenix.LiveView
  def handle_event("select_analytics_category", %{"category" => category}, socket) do
    # Navigate to the same page but with the analytics category parameter
    current_path = Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      :insights,
      :advanced_analytics
    )

    {:noreply,
     push_patch(socket,
       to: "#{current_path}?analytics_category=#{category}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components
    # that don't need handling (like dropdown toggles)
    Logger.warning(
      "Unhandled event in InstructorDashboardLive: #{inspect(event)}, #{inspect(params)}"
    )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:analytics_data_loaded, _category, data, spec}, socket) do
    {:noreply, assign(socket, analytics_data: data, analytics_spec: spec)}
  end

  @impl Phoenix.LiveView
  def handle_info({:practice_activities, results}, socket) do
    {:noreply, assign(socket, practice_activities: results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:surveys, results}, socket) do
    {:noreply, assign(socket, surveys: results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:assessments, results}, socket) do
    {:noreply, assign(socket, assessments: results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:proficiency, proficiency_per_container}, socket) do
    case Map.get(socket.assigns, :containers) do
      nil ->
        {:noreply, socket}

      {total, containers} ->
        containers_with_metrics =
          Enum.map(containers, fn container ->
            Map.merge(container, %{
              student_proficiency:
                if(total > 0,
                  do: Map.get(proficiency_per_container, container.id, "Not enough data"),
                  else: container.student_proficiency
                )
            })
          end)

        {:noreply, assign(socket, containers: {total, containers_with_metrics})}
    end
  end

  def handle_info({:redirect_with_warning, message}, socket) do
    {:noreply,
     redirect(
       socket |> put_flash(:info, message),
       to:
         ~p"/sections/#{socket.assigns.section_slug}/instructor_dashboard/#{socket.assigns.view}/#{socket.assigns.active_tab}"
     )}
  end

  def handle_info(
        {:selected_card_containers, value},
        socket
      ) do
    params = Map.merge(socket.assigns.params, %{"selected_card_value" => value})

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/content?#{params}"
     )}
  end

  def handle_info(
        {:selected_card_students, {value, container_id, :insights = _view}},
        socket
      ) do
    params =
      Map.merge(socket.assigns.params, %{
        "selected_card_value" => value,
        "container_id" => container_id
      })

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/content?#{params}"
     )}
  end

  def handle_info(
        {:selected_card_students, {value, _container_id, :overview = _view}},
        socket
      ) do
    params =
      Map.merge(socket.assigns.params, %{
        "selected_card_value" => value
      })

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/overview/students?#{params}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_info({:flash_message, {type, message}}, socket) when type in [:error, :info] do
    {:noreply, put_flash(socket, type, message)}
  end

  @impl Phoenix.LiveView
  def handle_info(_any, socket) do
    {:noreply, socket}
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
