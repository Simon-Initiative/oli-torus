defmodule OliWeb.Delivery.StudentDashboard.StudentDashboardLive do
  use OliWeb, :live_view

  alias OliWeb.Delivery.StudentDashboard.Components.Helpers

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    {:noreply,
     assign(socket, params: params, active_tab: String.to_existing_atom(params["active_tab"]))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <Helpers.section_details_header section_title={@section.title} student_name={@student.name}/>
      <Helpers.student_details student={@student} />
      <Helpers.tabs active_tab={@active_tab} section_slug={@section_slug} student_id={@student.id} preview_mode={@preview_mode} />
      <%= render_tab(assigns) %>
    """
  end

  defp render_tab(%{active_tab: :content} = assigns) do
    ~H"""
      <.live_component
      id="content_tab"
      module={OliWeb.Delivery.StudentDashboard.Components.ContentTab}
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
             socket.assigns.section_slug,
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
             socket.assigns.section_slug,
             :students
           )
       )}
    end
  end
end
