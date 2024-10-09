defmodule OliWeb.Workspaces.Instructor.DashboardLive do
  use OliWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    section = socket.assigns.section

    {:ok,
     assign(socket,
       resource_slug: section.slug,
       resource_title: section.title,
       active_workspace: :instructor,
       active_tab: :course_content
     )}
  end

  @impl Phoenix.LiveView

  def handle_params(%{"view" => "overview", "active_tab" => "course_content"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "overview", "active_tab" => "students"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "overview", "active_tab" => "quiz_scores"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "overview", "active_tab" => "recommended_actions"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "content"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "learning_objectives"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "scored_activities"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "practice_activities"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "surveys"}, _, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "manage"} = _params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_params(%{"view" => "activity"} = _params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1 class="flex flex-col w-full h-screen items-center justify-center">
      Placeholder for Instructor Dashboard
    </h1>
    """
  end
end
