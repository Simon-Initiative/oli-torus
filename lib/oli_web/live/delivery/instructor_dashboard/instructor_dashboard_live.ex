defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias OliWeb.Components.Delivery.InstructorDashboard.TabLink
  alias Oli.Delivery.RecommendedActions
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    ctx = SessionContext.init(socket, session)

    {:ok, assign(socket, ctx: ctx)}
  end

  defp do_handle_students_params(%{"active_tab" => active_tab} = params, _, socket) do
    params = OliWeb.Components.Delivery.Students.decode_params(params)

    socket =
      socket
      |> assign(params: params, view: :reports, active_tab: String.to_existing_atom(active_tab))
      |> assign(users: Helpers.get_students(socket.assigns.section, params))
      |> assign(dropdown_options: get_dropdown_options(socket.assigns.section))

    socket =
      if params.container_id do
        selected_container =
          socket.assigns.section
          |> Helpers.get_containers()
          |> elem(1)
          |> Enum.find(&(&1.id == params.container_id))

        assign(socket, :selected_container, selected_container)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "reports", "active_tab" => "content", "container_id" => _container_id} =
          params,
        uri,
        socket
      ),
      do: do_handle_students_params(params, uri, socket)

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "reports", "active_tab" => "students"} = params,
        uri,
        socket
      ),
      do: do_handle_students_params(params, uri, socket)

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "reports", "active_tab" => "learning_objectives"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(params: params, view: :reports, active_tab: :learning_objectives)
      |> assign_new(:objectives_tab, fn ->
        %{
          objectives: Sections.get_objectives_and_subobjectives(socket.assigns.section.slug),
          filter_options:
            Sections.get_units_and_modules_from_a_section(socket.assigns.section.slug)
        }
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"view" => "reports"} = params, _, socket) do
    active_tab =
      case params["active_tab"] do
        nil -> :content
        tab -> String.to_existing_atom(tab)
      end

    socket =
      socket
      |> assign(params: params, view: :reports, active_tab: active_tab)
      |> assign_new(:containers, fn ->
        Helpers.get_containers(socket.assigns.section)
      end)

    {:noreply, socket}
  end

  def handle_params(
        %{"view" => "overview", "active_tab" => "scored_activities"} = params,
        _,
        socket
      ) do
    socket =
      socket
      |> assign(
        params: params,
        view: :overview,
        active_tab: :scored_activities
      )
      |> assign_new(:students, fn ->
        Sections.enrolled_students(socket.assigns.section.slug)
        |> Enum.reject(fn s -> s.user_role_id != 4 end)
      end)
      |> assign_new(:assessments, fn %{students: students} ->
        Helpers.get_assessments(socket.assigns.section, students)
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
        %{
          "view" => "overview",
          "section_slug" => _section_slug,
          "active_tab" => "recommended_actions"
        } = params,
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
      case params["active_tab"] do
        value when value in [nil, "course_content"] ->
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
          |> assign(view: :overview, params: params, active_tab: String.to_existing_atom(tab))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    allowed_routes = [
      {nil, nil},
      {"overview", "course_content"},
      {"overview", "scored_activities"},
      {"overview", "recommended_actions"},
      {"reports", nil},
      {"reports", "content"},
      {"reports", "students"},
      {"reports", "learning_objectives"},
      {"reports", "quiz_scores"},
      {"reports", "course_discussion"},
      {"manage", nil},
      {"discussions", nil}
    ]

    if {params["view"], params["active_tab"]} in allowed_routes do
      view =
        case params["view"] do
          nil -> :overview
          tab -> String.to_existing_atom(tab)
        end

      active_tab =
        case params["active_tab"] do
          nil -> nil
          tab -> String.to_existing_atom(tab)
        end

      {:noreply,
       assign(socket,
         params: params,
         view: view,
         active_tab: active_tab
       )}
    else
      {:noreply,
       assign(socket,
         params: params,
         view: :not_found
       )}
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
        label: "Scored Activities",
        path: path_for(:overview, :scored_activities, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:scored_activities, active_tab)
      },
      %TabLink{
        label: "Recommended Actions",
        path: path_for(:overview, :recommended_actions, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:recommended_actions, active_tab)
      }
    ]
  end

  defp container_details_tab(section_slug, preview_mode, selected_container) do
    [
      %TabLink{
        label: fn -> render_container_tab_detail(%{title: selected_container.title}) end,
        path: path_for(:reports, :content, section_slug, preview_mode),
        badge: nil,
        active: true
      }
    ]
  end

  defp render_container_tab_detail(assigns) do
    ~H"""
    <div class="flex gap-2 items-center">
      <i class="fa-solid fa-chevron-left" />
      <span><%= @title %></span>
    </div>
    """
  end

  defp reports_tabs(section_slug, preview_mode, active_tab) do
    [
      %TabLink{
        label: "Content",
        path: path_for(:reports, :content, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:content, active_tab)
      },
      %TabLink{
        label: "Students",
        path: path_for(:reports, :students, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:students, active_tab)
      },
      %TabLink{
        label: "Learning Objectives",
        path: path_for(:reports, :learning_objectives, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:learning_objectives, active_tab)
      },
      %TabLink{
        label: "Quiz Scores",
        path: path_for(:reports, :quiz_scores, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:quiz_scores, active_tab)
      },
      %TabLink{
        label: "Course Discussion",
        path: path_for(:reports, :course_discussion, section_slug, preview_mode),
        badge: nil,
        active: is_active_tab?(:course_discussion, active_tab)
      }
    ]
  end

  @impl Phoenix.LiveView
  def render(%{view: :overview, active_tab: :scored_activities} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

      <div class="mx-10 mb-10">
        <.live_component id="scored_activities_tab"
          module={OliWeb.Components.Delivery.ScoredActivities}
          section={@section}
          params={@params}
          assessments={@assessments}
          students={@students}
          scripts={@scripts}
          activity_types_map={@activity_types_map}
          view={@view}
          ctx={@ctx} />
      </div>
    """
  end

  def render(%{view: :overview, active_tab: :recommended_actions} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

      <div class="mx-10 mb-10 p-6 bg-white dark:bg-gray-800 shadow-sm">
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

  def render(%{view: :overview} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={overview_tabs(@section_slug, @preview_mode, @active_tab)} />

      <div class="mx-10 mb-10 bg-white dark:bg-gray-800 shadow-sm">
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
        %{view: :reports, active_tab: :content, params: %{container_id: _container_id}} = assigns
      ) do
    ~H"""
      <InstructorDashboard.tabs tabs={container_details_tab(@section_slug, @preview_mode, @selected_container)} />

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
    """
  end

  def render(%{view: :reports, active_tab: :content} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={reports_tabs(@section_slug, @preview_mode, @active_tab)} />

      <.live_component
        id="content_table"
        module={OliWeb.Components.Delivery.Content}
        params={@params}
        section_slug={@section.slug}
        view={@view}
        containers={@containers}
        patch_url_type={:instructor_dashboard}
      />
    """
  end

  def render(%{view: :reports, active_tab: :students} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={reports_tabs(@section_slug, @preview_mode, @active_tab)} />

      <.live_component
        id="students_table"
        module={OliWeb.Components.Delivery.Students}
        params={@params}
        ctx={@ctx}
        section={@section}
        view={@view}
        students={@users}
        dropdown_options={@dropdown_options}
      />
    """
  end

  def render(%{view: :reports, active_tab: :learning_objectives} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={reports_tabs(@section_slug, @preview_mode, @active_tab)} />

      <.live_component
        id="objectives_table"
        module={OliWeb.Components.Delivery.LearningObjectives}
        params={@params}
        section_slug={@section.slug}
        view={@view}
        objectives_tab={@objectives_tab}
        patch_url_type={:instructor_dashboard}
      />
    """
  end

  def render(%{view: :reports, active_tab: :quiz_scores} = assigns) do
    ~H"""
      <InstructorDashboard.tabs tabs={reports_tabs(@section_slug, @preview_mode, @active_tab)} />

      <.live_component
        id="quiz_scores_table"
        module={OliWeb.Components.Delivery.QuizScores}
        params={@params}
        section={@section}
        view={@view}
        patch_url_type={:quiz_scores_instructor}
      />
    """
  end

  def render(%{view: :reports, active_tab: :course_discussion} = assigns) do
    %{slug: revision_slug} = DeliveryResolver.root_container(assigns.section_slug)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_section(
        revision_slug,
        assigns.section_slug
      )

    assigns =
      Map.merge(
        assigns,
        %{revision_slug: revision_slug, collab_space_config: collab_space_config}
      )

    ~H"""
      <InstructorDashboard.tabs tabs={reports_tabs(@section_slug, @preview_mode, @active_tab)} />

      <div class="mx-10 mb-10">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
         <%= if !is_nil(@collab_space_config) do %>
          <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceView, id: "course_discussion",
            session: %{
              "collab_space_config" => @collab_space_config,
              "section_slug" => @section_slug,
              "resource_slug" => @revision_slug,
              "is_instructor" => true,
              "title" => "Course Discussion"
            })
          %>
          <% else %>
              <h6>There is no collaboration space configured for this Course</h6>
          <% end %>
        </div>
      </div>
    """
  end

  def render(%{view: :manage} = assigns) do
    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
          <%= live_render(@socket, OliWeb.Sections.OverviewView, id: "overview", session: %{"section_slug" => @section_slug}) %>
        </div>
      </div>
    """
  end

  def render(%{view: :discussions} = assigns) do
    ~H"""
      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
        ctx={@ctx}
        params={@params}
        section={@section}
        />
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
          %{value: :non_students, label: "Non-Students"}
        ]

      false ->
        [
          %{value: :enrolled, label: "Enrolled"},
          %{value: :suspended, label: "Suspended"},
          %{value: :non_students, label: "Non-Students"}
        ]

      _ ->
        []
    end
  end
end
