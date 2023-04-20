defmodule OliWeb.Delivery.StudentDashboard.StudentDashboardLive do
  use OliWeb, :live_view

  alias OliWeb.Delivery.StudentDashboard.Components.Helpers
  alias alias Oli.Delivery.Sections
  alias Oli.Delivery.Metrics

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    survey_responses =
      case socket.assigns.section do
        %{required_survey_resource_id: nil} ->
          []

        %{required_survey_resource_id: required_survey_resource_id} ->
          Oli.Delivery.Attempts.summarize_survey(
            required_survey_resource_id,
            socket.assigns.student.id
          )
      end

    {:ok, assign(socket, survey_responses: survey_responses)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "content"} = params, _, socket) do
    socket =
      socket
      |> assign(
        params: params,
        active_tab: String.to_existing_atom(params["active_tab"])
      )
      |> assign_new(:containers, fn ->
        get_containers(socket.assigns.section, socket.assigns.student.id)
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    {:noreply,
     assign(socket,
       params: params,
       active_tab: String.to_existing_atom(params["active_tab"])
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <Helpers.section_details_header section_title={@section.title} student_name={@student.name}/>
      <Helpers.student_details survey_responses={@survey_responses || []} student={@student} />
      <Helpers.tabs active_tab={@active_tab} section_slug={@section.slug} student_id={@student.id} preview_mode={@preview_mode} />
      <%= render_tab(assigns) %>
    """
  end

  defp render_tab(%{active_tab: :content} = assigns) do
    ~H"""
      <.live_component
      id="content_tab"
      module={OliWeb.Delivery.StudentDashboard.Components.ContentTab}
      params={@params}
      section_slug={@section.slug}
      containers={@containers}
      student_id={@student.id}
      />
    """
  end

  defp render_tab(%{active_tab: :learning_objectives} = assigns) do
    ~H"""
      <.live_component
      id="learning_objectives_tab"
      module={OliWeb.Delivery.StudentDashboard.Components.LearningObjectivesTab}
      />
    """
  end

  defp render_tab(%{active_tab: :quizz_scores} = assigns) do
    ~H"""
      <.live_component
      id="quizz_scores_tab"
      module={OliWeb.Delivery.StudentDashboard.Components.QuizzScoresTab}
      />
    """
  end

  defp render_tab(%{active_tab: :progress} = assigns) do
    ~H"""
      <.live_component
      id="progress_tab"
      module={OliWeb.Delivery.StudentDashboard.Components.ProgressTab}
      />
    """
  end

  @impl Phoenix.LiveView
  def handle_event("breadcrumb-navigate", _unsigned_params, socket) do
    if socket.assigns.preview_mode do
      {:noreply,
       redirect(socket,
         to:
           Routes.instructor_dashboard_path(
             socket,
             :preview,
             socket.assigns.section.slug,
             :students
           )
       )}
    else
      {:noreply,
       redirect(socket,
         to:
           Routes.live_path(
             socket,
             OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
             socket.assigns.section.slug,
             :students
           )
       )}
    end
  end

  defp get_containers(section, student_id) do
    {total_count, containers} = Sections.get_units_and_modules_containers(section.slug)

    student_progress =
      get_students_progress(
        total_count,
        containers,
        section.id,
        student_id
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

  defp get_students_progress(0, pages, section_id, student_id) do
    page_ids = Enum.map(pages, fn p -> p.id end)

    Metrics.progress_across_for_pages(
      section_id,
      page_ids,
      student_id
    )
  end

  defp get_students_progress(_total_count, containers, section_id, student_id) do
    container_ids = Enum.map(containers, fn c -> c.id end)

    Metrics.progress_across(
      section_id,
      container_ids,
      student_id
    )
  end
end
