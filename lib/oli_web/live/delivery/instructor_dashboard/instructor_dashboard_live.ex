defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  alias Oli.Delivery.Metrics
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  use OliWeb.Common.Modal

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "students"} = params, _, socket) do
    params = OliWeb.Components.Delivery.Students.decode_params(params)

    socket =
      socket
      |> assign(params: params, active_tab: :students)
      |> assign_new(:students, fn -> get_students(socket.assigns.section, params) end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "content"} = params, _, socket) do
    socket =
      socket
      |> assign(params: params, active_tab: String.to_existing_atom(params["active_tab"]))
      |> assign_new(:containers, fn -> get_containers(socket.assigns.section) end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "learning_objectives"} = params, _, socket) do
    socket =
      socket
      |> assign(params: params, active_tab: String.to_existing_atom(params["active_tab"]))
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
  def handle_params(params, _, socket) do
    {:noreply,
     assign(socket, params: params, active_tab: String.to_existing_atom(params["active_tab"]))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.tabs active_tab={@active_tab} section_slug={@section_slug} preview_mode={@preview_mode} />
      <%= render_tab(assigns) %>
    """
  end

  defp render_tab(%{active_tab: :learning_objectives} = assigns) do
    ~H"""
      <.live_component
        id="objectives_table"
        module={OliWeb.Components.Delivery.LearningObjectives}
        params={@params}
        section_slug={@section.slug}
        objectives_tab={@objectives_tab}
        patch_url_type={:instructor_dashboard}
      />
    """
  end

  defp render_tab(%{active_tab: :students} = assigns) do
    ~H"""
      <.live_component
      id="students_table"
      module={OliWeb.Components.Delivery.Students}
      params={@params}
      context={@context}
      section={@section}
      students={@students}
      />
    """
  end

  defp render_tab(%{active_tab: :quiz_scores} = assigns) do
    ~H"""
      <.live_component
        id="quiz_scores_table"
        module={OliWeb.Components.Delivery.QuizScores}
        params={@params}
        section={@section}
        patch_url_type={:quiz_scores_instructor}
      />
    """
  end

  defp render_tab(%{active_tab: :content} = assigns) do
    ~H"""
      <.live_component
      id="content_table"
      module={OliWeb.Components.Delivery.Content}
      params={@params}
      section_slug={@section.slug}
      containers={@containers}
      patch_url_type={:instructor_dashboard}
      />
    """
  end

  defp render_tab(%{active_tab: :manage} = assigns) do
    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
          <%= live_render(@socket, OliWeb.Sections.OverviewView, id: "overview", session: %{"section_slug" => @section_slug}) %>
        </div>
      </div>
    """
  end

  defp render_tab(%{active_tab: :course_discussion} = assigns) do
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
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
         <%= if @collab_space_config do%>
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

  defp render_tab(%{active_tab: :discussions} = assigns) do
    ~H"""
      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
        params={@params}
        section={@section}
        />
    """
  end

  defp render_tab(assigns) do
    ~H"""
      <p class="container mx-auto">Not available yet</p>
    """
  end

  defp get_students(section, params) do
    # TODO get real student engagement and student mastery values
    # when those metrics are ready (see Oli.Delivery.Metrics)
    case params.page_id do
      nil ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress(section.id, params.container_id)
        |> add_students_last_interaction(section.slug)
        |> add_students_overall_mastery(section.slug)
        |> add_students_engagement(section.slug)

      page_id ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress_for_page(section.id, page_id)
        |> add_students_last_interaction_for_page(section.slug, page_id)
        |> add_students_overall_mastery_for_page(section.slug, page_id)
        |> add_students_engagement_for_page(section.slug, page_id)
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

    # TODO get real student engagement and student mastery values
    # when those metrics are ready (see Oli.Delivery.Metrics)

    containers_with_metrics =
      Enum.map(containers, fn container ->
        Map.merge(container, %{
          progress: student_progress[container.id] || 0.0,
          student_engagement: Enum.random(["Low", "Medium", "High", "Not enough data"]),
          student_mastery: Enum.random(["Low", "Medium", "High", "Not enough data"])
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

  defp add_students_last_interaction(students, section_slug) do
    students_last_interaction = Metrics.students_last_interaction(section_slug)

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

  defp add_students_overall_mastery(students, _section_slug) do
    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_mastery: Enum.random(["Low", "Medium", "High", "Not enough data"])
      })
    end)
  end

  defp add_students_overall_mastery_for_page(students, _section_slug, _page_id) do
    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_mastery: Enum.random(["Low", "Medium", "High", "Not enough data"])
      })
    end)
  end

  defp add_students_engagement(students, _section_slug) do
    Enum.map(students, fn student ->
      Map.merge(student, %{
        engagement: Enum.random(["Low", "Medium", "High", "Not enough data"])
      })
    end)
  end

  defp add_students_engagement_for_page(students, _section_slug, _page_id) do
    Enum.map(students, fn student ->
      Map.merge(student, %{
        engagement: Enum.random(["Low", "Medium", "High", "Not enough data"])
      })
    end)
  end
end
