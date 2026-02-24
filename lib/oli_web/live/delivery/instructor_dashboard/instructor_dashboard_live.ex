defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  require Logger

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.RevisitCache
  alias Oli.Features
  alias Oli.InstructorDashboard.DataSnapshot
  alias Oli.InstructorDashboard.OracleRegistry
  alias Oli.ScopedFeatureFlags
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
    {:ok,
     socket
     |> assign(:prototype_dashboard_store, start_inprocess_store())
     |> assign(:prototype_dashboard_revisit_cache, start_revisit_cache())}
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

        socket
        |> assign(:selected_container, selected_container)
        |> assign(
          :navigator_items,
          if(selected_container,
            do:
              Oli.Delivery.Sections.SectionResourceDepot.containers(socket.assigns.section.id,
                numbering_level: selected_container.numbering_level
              ),
            else: Oli.Delivery.Sections.SectionResourceDepot.containers(socket.assigns.section.id)
          )
        )
      else
        socket
        |> assign(
          :navigator_items,
          Oli.Delivery.Sections.SectionResourceDepot.containers(socket.assigns.section.id)
        )
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
              exclude_sub_objectives: false,
              include_related_activities_count: true
            ),
          navigator_items:
            Oli.Delivery.Sections.SectionResourceDepot.containers(socket.assigns.section.id,
              numbering_level: {:in, [1, 2]}
            )
        }
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "scored_pages"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :scored_pages
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:scored_pages, fn %{students: students} ->
        result = Helpers.get_assessments(socket.assigns.section, students)

        pid = self()

        Task.async(fn ->
          result_with_metrics = Helpers.load_metrics(result, socket.assigns.section, students)
          send(pid, {:pages, :scored, result_with_metrics})
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
      |> assign_new(:list_lti_activities, fn ->
        Enum.map(Oli.Activities.list_lti_activity_registrations(), & &1.id)
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "practice_pages"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :practice_pages
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:practice_pages, fn %{students: students} ->
        result = Helpers.get_practice_pages(socket.assigns.section, students)

        pid = self()

        Task.async(fn ->
          result_with_metrics = Helpers.load_metrics(result, socket.assigns.section, students)
          send(pid, {:pages, :practice, result_with_metrics})
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
      |> assign_new(:list_lti_activities, fn ->
        Enum.map(Oli.Activities.list_lti_activity_registrations(), & &1.id)
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
        %{"view" => "insights", "active_tab" => "analytics"} = params,
        _,
        socket
      ) do
    if analytics_enabled?(socket.assigns.section) do
      section_id = socket.assigns.section.id

      {load_state, comprehensive_section_analytics} =
        case Oli.InstructorDashboard.Oracles.SectionAnalytics.section_analytics_loaded?(
               section_id
             ) do
          {:ok, true} ->
            {:loaded,
             Oli.InstructorDashboard.Oracles.SectionAnalytics.comprehensive_section_analytics(
               section_id
             )}

          {:ok, false} ->
            {:not_loaded, nil}

          {:error, reason} ->
            error_message = if is_binary(reason), do: reason, else: inspect(reason)
            {{:error, error_message}, nil}
        end

      socket =
        socket
        |> assign(
          params: params,
          view: :insights,
          active_tab: :analytics,
          selected_analytics_category: params["analytics_category"],
          analytics_data: nil,
          analytics_spec: nil,
          section_analytics_load_state: load_state,
          comprehensive_section_analytics: comprehensive_section_analytics
        )
        |> maybe_load_analytics_data()

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(:info, "Analytics is not enabled for this section.")
       |> redirect(
         to:
           path_for(
             :insights,
             :content,
             socket.assigns.section.slug,
             socket.assigns.preview_mode
           )
       )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "insights", "active_tab" => "dashboard"} = params,
        _,
        socket
      ) do
    scope_selector = Map.get(params, "dashboard_scope", "course")

    socket =
      socket
      |> assign(
        params: params,
        view: :insights,
        active_tab: :dashboard,
        prototype_dashboard_scope: scope_selector
      )
      |> assign_new(:containers, fn ->
        Helpers.get_containers(socket.assigns.section)
      end)
      |> load_prototype_dashboard()

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
      {"insights", "dashboard"},
      {"insights", "learning_objectives"},
      {"insights", "scored_pages"},
      {"insights", "practice_pages"},
      {"insights", "surveys"},
      {"insights", "analytics"},
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

  defp insights_tabs(section, preview_mode, active_tab) do
    section_slug = section.slug

    base_tabs = [
      %TabLink{
        label: "Content",
        path: path_for(:insights, :content, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:content, active_tab)
      },
      %TabLink{
        label: "Dashboard",
        path: path_for(:insights, :dashboard, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:dashboard, active_tab)
      },
      %TabLink{
        label: "Learning Objectives",
        path: path_for(:insights, :learning_objectives, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:learning_objectives, active_tab)
      },
      %TabLink{
        label: "Scored Pages",
        path: path_for(:insights, :scored_pages, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:scored_pages, active_tab)
      },
      %TabLink{
        label: "Practice Pages",
        path: path_for(:insights, :practice_pages, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:practice_pages, active_tab)
      },
      %TabLink{
        label: "Surveys",
        path: path_for(:insights, :surveys, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:surveys, active_tab)
      }
    ]

    if analytics_enabled?(section) do
      base_tabs ++
        [
          %TabLink{
            label: "Analytics",
            path: path_for(:insights, :analytics, section_slug, preview_mode),
            badge: nil,
            active: is_active_tab?(:analytics, active_tab)
          }
        ]
    else
      base_tabs
    end
  end

  defp analytics_enabled?(section) do
    Features.enabled?("clickhouse-olap") and
      ScopedFeatureFlags.enabled?(:instructor_dashboard_analytics, section)
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
        active_tab={@active_tab}
        students={@users}
        certificate={@certificate}
        certificate_pending_email_notification_count={@certificate_pending_email_notification_count}
        dropdown_options={@dropdown_options}
        navigator_items={@navigator_items}
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
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

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
        active_tab={@active_tab}
        students={@users}
        dropdown_options={@dropdown_options}
        navigator_items={@navigator_items}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :content} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id="content_table"
        module={OliWeb.Components.Delivery.Content}
        params={@params}
        section_slug={@section.slug}
        view={@view}
        active_tab={@active_tab}
        containers={@containers}
        patch_url_type={:instructor_dashboard}
      />
    </div>
    <HTMLComponents.view_example_student_progress_modal />
    """
  end

  def render(%{view: :insights, active_tab: :learning_objectives} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto">
      <.live_component
        id={"objectives_table_#{@section_slug}"}
        module={OliWeb.Components.Delivery.LearningObjectives}
        params={@params}
        view={@view}
        objectives_tab={@objectives_tab}
        section_slug={@section_slug}
        section_id={@section.id}
        section_title={@section.title}
        v25_migration={@section.v25_migration}
        patch_url_type={:instructor_dashboard}
        current_user={@current_user}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :scored_pages} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10">
      <.live_component
        id="scored_pages_tab"
        module={OliWeb.Components.Delivery.Pages}
        section={@section}
        params={@params}
        pages={@scored_pages}
        students={@students}
        scripts={@scripts}
        activity_types_map={@activity_types_map}
        list_lti_activities={@list_lti_activities}
        view={@view}
        active_tab={@active_tab}
        ctx={@ctx}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :practice_pages} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10">
      <.live_component
        id="practice_pages_tab"
        module={OliWeb.Components.Delivery.Pages}
        section={@section}
        params={@params}
        pages={@practice_pages}
        students={@students}
        scripts={@scripts}
        activity_types_map={@activity_types_map}
        list_lti_activities={@list_lti_activities}
        view={@view}
        active_tab={@active_tab}
        ctx={@ctx}
      />
    </div>
    """
  end

  def render(%{view: :insights, active_tab: :surveys} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10">
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

  def render(%{view: :insights, active_tab: :analytics} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <.live_component
      id="section_analytics"
      module={OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics}
      section={@section}
      selected_analytics_category={@selected_analytics_category}
      comprehensive_section_analytics={@comprehensive_section_analytics}
      section_analytics_load_state={@section_analytics_load_state}
      analytics_data={@analytics_data}
      analytics_spec={@analytics_spec}
    />
    """
  end

  def render(%{view: :insights, active_tab: :dashboard} = assigns) do
    ~H"""
    <InstructorDashboard.tabs tabs={insights_tabs(@section, @preview_mode, @active_tab)} />

    <div class="container mx-auto mb-10">
      <div class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-3">
          <form phx-change="prototype_dashboard_scope_changed">
            <label for="prototype_dashboard_scope" class="block text-sm font-semibold mb-1">
              Scope
            </label>
            <select
              id="prototype_dashboard_scope"
              name="scope"
              class="form-select"
              value={@prototype_dashboard_scope}
            >
              <option value="course">Course (all content)</option>
              <%= for {label, value} <- prototype_dashboard_scope_options(@containers) do %>
                <option value={value}>{label}</option>
              <% end %>
            </select>
          </form>

          <button class="btn btn-secondary" phx-click="prototype_dashboard_reload">
            Reload Snapshot
          </button>
        </div>
      </div>

      <div class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <h3 class="font-semibold mb-2">Lane 1 Runtime Status</h3>
        <pre class="text-xs whitespace-pre-wrap">{@prototype_dashboard.runtime_status_text}</pre>
      </div>

      <div class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <h3 class="font-semibold mb-2">Prototype Tile: Progress</h3>
        <pre class="text-xs whitespace-pre-wrap">{@prototype_dashboard.progress_text}</pre>
      </div>

      <div class="p-4 bg-white dark:bg-gray-800 shadow-sm">
        <h3 class="font-semibold mb-2">Prototype Tile: Progress / Proficiency</h3>
        <pre class="text-xs whitespace-pre-wrap">{@prototype_dashboard.student_support_text}</pre>
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

  defp maybe_load_analytics_data(socket) do
    case {socket.assigns[:selected_analytics_category],
          socket.assigns[:section_analytics_load_state]} do
      {nil, _} ->
        socket

      {_, state} when state != :loaded ->
        socket

      {category, :loaded} ->
        pid = self()

        Task.async(fn ->
          {data, spec} = get_analytics_data_and_spec(category, socket.assigns.section.id)
          send(pid, {:analytics_data_loaded, category, data, spec})
        end)

        socket
    end
  end

  defp get_analytics_data_and_spec(category, section_id) do
    # For engagement analytics, use default filters for initial load
    case category do
      "engagement" ->
        # Get resource title map for engagement analytics
        resource_title_map =
          OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics.load_resource_title_map(
            section_id
          )

        # Get section to determine default date range
        section = Oli.Delivery.Sections.get_section!(section_id)
        # Use section dates as default filters, fallback to relative dates if not set
        start_date =
          case section.start_date do
            nil -> Date.add(Date.utc_today(), -30) |> Date.to_string()
            start_date -> DateTime.to_date(start_date) |> Date.to_string()
          end

        end_date =
          case section.end_date do
            nil -> Date.utc_today() |> Date.to_string()
            end_date -> DateTime.to_date(end_date) |> Date.to_string()
          end

        Logger.info("=== PARENT LIVEVIEW FILTER DEFAULTS ===")
        Logger.info("Section ID: #{section_id}")
        Logger.info("Section start_date: #{inspect(section.start_date)}")
        Logger.info("Section end_date: #{inspect(section.end_date)}")
        Logger.info("Calculated start_date: #{start_date}")
        Logger.info("Calculated end_date: #{end_date}")
        Logger.info("=== END PARENT LIVEVIEW FILTER DEFAULTS ===")
        max_pages = 25

        OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics.get_engagement_analytics_with_filters(
          section_id,
          start_date,
          end_date,
          max_pages,
          resource_title_map
        )

      _ ->
        # Delegate to the component's analytics functions for other categories
        OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics.get_analytics_data_and_spec(
          category,
          section_id
        )
    end
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
  def handle_info({:pages, :practice, results}, socket) do
    {:noreply, assign(socket, practice_pages: results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:pages, :scored, results}, socket) do
    {:noreply, assign(socket, scored_pages: results)}
  end

  @impl Phoenix.LiveView
  def handle_info({:surveys, results}, socket) do
    {:noreply, assign(socket, surveys: results)}
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
        {:selected_card_pages, value, view},
        socket
      ) do
    params = Map.merge(socket.assigns.params, %{"selected_card_value" => value})

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/#{Atom.to_string(view)}?#{params}"
     )}
  end

  def handle_info(
        {:selected_activity_card, value, view},
        socket
      ) do
    params =
      Map.merge(socket.assigns.params, %{"selected_activity_card_value" => value})
      |> Map.drop(["selected_activity"])

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/#{Atom.to_string(view)}?#{params}"
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

  def handle_info({:show_email_modal, caller_assigns}, socket) do
    # Only send update if the Students component is currently rendered
    case {socket.assigns.view, socket.assigns.active_tab} do
      {:overview, :students} ->
        send_update(OliWeb.Components.Delivery.Students,
          id: "students_table",
          show_email_modal: true
        )

      {:insights, :content} ->
        send_update(OliWeb.Components.Delivery.Students,
          id: "container_details_table",
          show_email_modal: true
        )

      {:insights, :learning_objectives} ->
        send_update(OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList,
          id: caller_assigns.email_handler_id,
          show_email_modal: true
        )

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_info({:hide_email_modal, email_handler_id}, socket) do
    # Only send update if the Students component is currently rendered
    case {socket.assigns.view, socket.assigns.active_tab} do
      {:overview, :students} ->
        send_update(OliWeb.Components.Delivery.Students,
          id: email_handler_id || "students_table",
          show_email_modal: false
        )

      {:insights, :content} ->
        send_update(OliWeb.Components.Delivery.Students,
          id: email_handler_id || "container_details_table",
          show_email_modal: false
        )

      {:insights, :learning_objectives} ->
        send_update(OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList,
          id: email_handler_id,
          show_email_modal: false
        )

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_info({:analytics_data_loaded, category, data, spec}, socket) do
    if socket.assigns.selected_analytics_category == category do
      {:noreply,
       assign(socket,
         analytics_data: data,
         analytics_spec: spec
       )}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:select_analytics_category, category}, socket) do
    # Navigate to the section analytics page with the selected category
    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/analytics?analytics_category=#{category}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView, component_id,
         loaded_data},
        socket
      ) do
    # Forward the async loaded data to the component
    Phoenix.LiveView.send_update(
      OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView,
      id: component_id,
      loaded_data: loaded_data
    )

    {:noreply, socket}
  end

  def handle_info(_any, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("prototype_dashboard_scope_changed", %{"scope" => scope}, socket) do
    params =
      socket.assigns.params
      |> Map.put("dashboard_scope", scope)

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/dashboard?#{params}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("prototype_dashboard_reload", _params, socket) do
    {:noreply, load_prototype_dashboard(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components that don't require handling
    Logger.warning(
      "Unhandled event in InstructorDashboardLive: #{inspect(event)}, #{inspect(params)}"
    )

    {:noreply, socket}
  end

  defp start_inprocess_store do
    {:ok, pid} = InProcessStore.start_link([])
    pid
  end

  defp start_revisit_cache do
    {:ok, pid} = RevisitCache.start_link([])
    pid
  end

  defp prototype_dashboard_scope_options({_, containers}) do
    Enum.map(containers, fn container ->
      {"#{container.label} - #{container.title}", "container:#{container.id}"}
    end)
  end

  defp prototype_dashboard_scope_options(_), do: []

  defp load_prototype_dashboard(socket) do
    scope_selector = Map.get(socket.assigns, :prototype_dashboard_scope, "course")
    scope = parse_prototype_scope(scope_selector)
    context = prototype_dashboard_context(socket, scope)
    cache_opts = prototype_dashboard_cache_opts(socket)

    revisit_hydration =
      hydrate_required_from_revisit_cache(
        socket.assigns.prototype_dashboard_revisit_cache,
        context,
        scope,
        cache_opts
      )

    scope_request = %{
      context: context,
      scope: scope,
      metadata: %{
        timezone: socket.assigns.browser_timezone || "Etc/UTC",
        source: :prototype_instructor_insights
      }
    }

    case DataSnapshot.get_or_build(scope_request,
           consumer_keys: [:progress_summary, :support_summary],
           cache_opts: cache_opts,
           runtime_results_provider: &prototype_runtime_results_provider/4
         ) do
      {:ok, bundle} ->
        persist_revisit_cache(
          socket.assigns.prototype_dashboard_revisit_cache,
          context,
          scope,
          bundle.snapshot.oracles
        )

        assign(socket, :prototype_dashboard, build_prototype_dashboard_payload(bundle, revisit_hydration))

      {:error, reason} ->
        assign(socket, :prototype_dashboard, prototype_dashboard_error_payload(reason))
    end
  end

  defp parse_prototype_scope("course"), do: %{container_type: :course}

  defp parse_prototype_scope("container:" <> id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> %{container_type: :container, container_id: parsed}
      _ -> %{container_type: :course}
    end
  end

  defp parse_prototype_scope(_), do: %{container_type: :course}

  defp prototype_dashboard_context(socket, scope) do
    %{
      dashboard_context_type: :section,
      dashboard_context_id: socket.assigns.section.id,
      user_id: prototype_dashboard_user_id(socket),
      scope: scope
    }
  end

  defp prototype_dashboard_user_id(socket) do
    cond do
      is_map(socket.assigns[:current_user]) and is_integer(socket.assigns.current_user.id) ->
        socket.assigns.current_user.id

      is_map(socket.assigns[:ctx]) and is_integer(socket.assigns.ctx.user_id) ->
        socket.assigns.ctx.user_id

      true ->
        1
    end
  end

  defp prototype_dashboard_cache_opts(socket) do
    [
      inprocess_store: socket.assigns.prototype_dashboard_store
    ]
  end

  defp hydrate_required_from_revisit_cache(revisit_cache, context, scope, cache_opts) do
    with {:ok, required_keys} <- prototype_required_oracle_keys(),
         {:ok, lookup} <-
           Cache.lookup_revisit(context.user_id, context, scope, required_keys,
             revisit_cache: revisit_cache,
             revisit_eligible: true
           ) do
      Enum.each(lookup.hits, fn {oracle_key, payload} ->
        _ =
          Cache.write_oracle(context, scope, oracle_key, payload, prototype_cache_meta(oracle_key), cache_opts)
      end)

      %{
        source: lookup.source,
        revisit_hits: map_size(lookup.hits),
        revisit_misses: length(lookup.misses)
      }
    else
      _ ->
        %{source: :none, revisit_hits: 0, revisit_misses: 0}
    end
  end

  defp prototype_required_oracle_keys do
    with {:ok, progress} <- OracleRegistry.dependencies_for(:progress_summary),
         {:ok, support} <- OracleRegistry.dependencies_for(:support_summary) do
      {:ok, Enum.uniq(progress.required ++ support.required)}
    end
  end

  defp persist_revisit_cache(revisit_cache, context, scope, oracles) when is_map(oracles) do
    Enum.each(oracles, fn {oracle_key, payload} ->
      meta = prototype_cache_meta(oracle_key)

      with {:ok, revisit_key} <- Key.revisit(context.user_id, context, scope, oracle_key, meta) do
        _ = RevisitCache.write(revisit_cache, revisit_key, payload)
      end
    end)
  end

  defp persist_revisit_cache(_revisit_cache, _context, _scope, _oracles), do: :ok

  defp prototype_runtime_results_provider(_request_token, misses, context, _scope) do
    Enum.reduce(misses, %{}, fn oracle_key, acc ->
      result =
        case OracleRegistry.oracle_module(oracle_key) do
          {:ok, module} ->
            load_oracle_result(module, oracle_key, context)

          {:error, reason} ->
            Result.error(oracle_key, reason)
        end

      Map.put(acc, oracle_key, result)
    end)
  end

  defp load_oracle_result(module, oracle_key, context) do
    case module.load(context, []) do
      {:ok, payload} ->
        Result.ok(oracle_key, payload,
          version: oracle_version(module),
          metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
        )

      {:error, reason} ->
        Result.error(oracle_key, reason,
          version: oracle_version(module),
          metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
        )
    end
  end

  defp oracle_version(module) do
    if function_exported?(module, :version, 0), do: module.version(), else: 1
  end

  defp prototype_cache_meta(oracle_key) do
    oracle_version =
      case OracleRegistry.oracle_module(oracle_key) do
        {:ok, module} -> oracle_version(module)
        _ -> 1
      end

    %{oracle_version: oracle_version, data_version: 1}
  end

  defp build_prototype_dashboard_payload(bundle, revisit_hydration) do
    progress_projection = Map.get(bundle.projections, :progress, %{})
    support_projection = Map.get(bundle.projections, :student_support, %{})
    oracle_sources = prototype_oracle_sources(bundle.snapshot.oracle_statuses)

    status_lines = [
      "request_token: #{bundle.request_token}",
      "scope: #{inspect(bundle.scope)}",
      "cache/revisit pre-hydration: #{inspect(revisit_hydration)}",
      "oracle sources: #{inspect(oracle_sources)}",
      "projection_statuses: #{inspect(bundle.projection_statuses)}",
      "parity fingerprint: #{bundle.parity.fingerprint}"
    ]

    %{
      runtime_status_text: Enum.join(status_lines, "\n"),
      progress_text: inspect(progress_projection, pretty: true, limit: :infinity),
      student_support_text: inspect(support_projection, pretty: true, limit: :infinity)
    }
  end

  defp prototype_oracle_sources(oracle_statuses) when is_map(oracle_statuses) do
    Enum.into(oracle_statuses, %{}, fn {oracle_key, status} ->
      source =
        status
        |> Map.get(:metadata, %{})
        |> Map.get(:source, :unknown)

      {oracle_key, source}
    end)
  end

  defp prototype_oracle_sources(_), do: %{}

  defp prototype_dashboard_error_payload(reason) do
    %{
      runtime_status_text: "snapshot load failed:\n#{inspect(reason, pretty: true)}",
      progress_text: "unavailable",
      student_support_text: "unavailable"
    }
  end
end
