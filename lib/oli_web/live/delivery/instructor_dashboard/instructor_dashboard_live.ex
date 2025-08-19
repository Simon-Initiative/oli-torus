defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

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
        comprehensive_section_analytics:
          Oli.Analytics.AdvancedAnalytics.comprehensive_section_analytics(
            socket.assigns.section.id
          )
      )

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
        id="objectives_table_#{@section_slug}"
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
              </div>
              <!-- Event Type Cards -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                <%= for line <- String.split(result.body, "\n") |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "event_type"))) do %>
                  <% parts = String.split(line, "\t") %>
                  <%= if length(parts) >= 6 do %>
                    <% [event_type, total_events, unique_users, earliest, latest, additional] =
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
        <div class="bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-lg p-6">
          <h2 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
            Available Analytics
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
            The system now captures and analyzes multiple types of learner interactions.
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div class="bg-gradient-to-br from-green-50 to-emerald-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Video Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Play/pause patterns</li>
                <li>• Completion rates</li>
                <li>• Seek behavior</li>
                <li>• Engagement time</li>
              </ul>
            </div>

            <div class="bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Assessment Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Activity performance</li>
                <li>• Page attempt scores</li>
                <li>• Part-level analysis</li>
                <li>• Success patterns</li>
              </ul>
            </div>

            <div class="bg-gradient-to-br from-purple-50 to-violet-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Engagement Analytics</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Page view patterns</li>
                <li>• Content preferences</li>
                <li>• Learning paths</li>
                <li>• Time-based trends</li>
              </ul>
            </div>

            <div class="bg-gradient-to-br from-yellow-50 to-orange-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Performance Insights</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Score distributions</li>
                <li>• Hint usage patterns</li>
                <li>• Feedback effectiveness</li>
                <li>• Learning objective alignment</li>
              </ul>
            </div>

            <div class="bg-gradient-to-br from-pink-50 to-rose-100 dark:from-gray-700 dark:to-gray-600 rounded-lg p-4">
              <h3 class="font-medium text-gray-900 dark:text-white mb-2">Cross-Event Analysis</h3>
              <ul class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                <li>• Multi-modal learning</li>
                <li>• Comprehensive summaries</li>
                <li>• User journey mapping</li>
                <li>• Predictive insights</li>
              </ul>
            </div>

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
      "activity_attempts" -> "Avg score: #{additional}"
      "page_attempts" -> "Avg score: #{additional}"
      "page_views" -> "#{additional} completed"
      "part_attempts" -> "Avg score: #{additional}"
      _ -> additional
    end
  end
end
