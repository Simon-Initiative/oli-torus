defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Delivery.{Metrics, Sections}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias OliWeb.Components.Delivery.InstructorDashboard.TabLink

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "reports", "active_tab" => "students"} = params,
        _,
        socket
      ) do
    params = OliWeb.Components.Delivery.Students.decode_params(params)

    socket =
      socket
      |> assign(params: params, view: :reports, active_tab: :students)
      |> assign(students: get_students(socket.assigns.section, params))
      |> assign(dropdown_options: get_dropdown_options(socket.assigns.section))

    {:noreply, socket}
  end

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
      |> assign_new(:containers, fn -> get_containers(socket.assigns.section) end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    allowed_routes = [
      {nil, nil},
      {"overview", nil},
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
  def render(%{view: :overview} = assigns) do
    ~H"""
      <InstructorDashboard.actions actions={[
        %InstructorDashboard.PriorityAction{ type: :email, title: "Send an email to students reminding of add/drop period", description: "Send before add/drop period ends on 9/23/2022", action_link: {"Send", "#"} }
      ]} />
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
        context={@context}
        section={@section}
        view={@view}
        students={@students}
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

      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
         <%= if @collab_space_config do %>
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

  def render(%{view: :discussion} = assigns) do
    ~H"""
      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
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

  defp get_students(section, params) do
    # when that metric is ready (see Oli.Delivery.Metrics)
    case params.page_id do
      nil ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress(section.id, params.container_id)
        |> add_students_last_interaction(section, params.container_id)
        |> add_students_overall_mastery(section, params.container_id)

      page_id ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress_for_page(section.id, page_id)
        |> add_students_last_interaction_for_page(section.slug, page_id)
        |> add_students_overall_mastery_for_page(section.slug, page_id)
    end
  end

  defp get_containers(section) do
    {total_count, containers} = Sections.get_units_and_modules_containers(section.slug)

    student_progress =
      get_students_progress(
        total_count,
        containers,
        section.id,
        Sections.count_enrollments(section.slug)
      )

    mastery_per_container = Metrics.mastery_per_container(section.slug)

    # when those metrics are ready (see Oli.Delivery.Metrics)

    containers_with_metrics =
      Enum.map(containers, fn container ->
        Map.merge(container, %{
          progress: student_progress[container.id] || 0.0,
          student_mastery: Map.get(mastery_per_container, container.id, "Not enough data")
        })
      end)

    {total_count, containers_with_metrics}
  end

  defp get_students_progress(0, pages, section_id, students_count) do
    page_ids = Enum.map(pages, fn p -> p.id end)

    Metrics.progress_across_for_pages(
      section_id,
      page_ids,
      [],
      students_count
    )
  end

  defp get_students_progress(_total_count, containers, section_id, students_count) do
    container_ids = Enum.map(containers, fn c -> c.id end)

    Metrics.progress_across(
      section_id,
      container_ids,
      [],
      students_count
    )
  end

  defp add_students_progress(students, section_id, container_id) do
    students_progress =
      Metrics.progress_for(section_id, Enum.map(students, & &1.id), container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{progress: Map.get(students_progress, student.id)})
    end)
  end

  defp add_students_progress_for_page(students, section_id, page_id) do
    students_progress =
      Metrics.progress_for_page(section_id, Enum.map(students, & &1.id), page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{progress: Map.get(students_progress, student.id)})
    end)
  end

  defp add_students_last_interaction(students, section, container_id) do
    students_last_interaction = Metrics.students_last_interaction_across(section, container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{last_interaction: Map.get(students_last_interaction, student.id)})
    end)
  end

  defp add_students_last_interaction_for_page(students, section_slug, page_id) do
    students_last_interaction = Metrics.students_last_interaction_for_page(section_slug, page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{last_interaction: Map.get(students_last_interaction, student.id)})
    end)
  end

  defp add_students_overall_mastery(students, section, container_id) do
    mastery_per_student = Metrics.mastery_per_student_across(section, container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_mastery: Map.get(mastery_per_student, student.id, "Not enough data")
      })
    end)
  end

  defp add_students_overall_mastery_for_page(students, section_slug, page_id) do
    mastery_per_student_for_page = Metrics.mastery_per_student_for_page(section_slug, page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_mastery: Map.get(mastery_per_student_for_page, student.id, "Not enough data")
      })
    end)
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
