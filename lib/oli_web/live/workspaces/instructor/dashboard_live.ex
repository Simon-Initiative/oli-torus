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
       active_view: :students,
       active_tab: :course_content
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"view" => "overview", "active_tab" => "students"} = _params,
        _uri,
        socket
      ) do
    socket = assign(socket, active_view: :students, active_tab: :students)
    {:noreply, socket}
  end

  def handle_params(%{"view" => "overview", "section_slug" => _section_slug} = _params, _, socket) do
    socket = assign(socket, active_view: :course_content, active_tab: :course_content)
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "content"} = _params, _uri, socket) do
    socket = assign(socket, active_view: :content, active_tab: :content)
    {:noreply, socket}
  end

  def handle_params(
        %{"view" => "insights", "active_tab" => "learning_objectives"} = _params,
        _uri,
        socket
      ) do
    socket = assign(socket, active_view: :learning_objectives, active_tab: :learning_objectives)
    {:noreply, socket}
  end

  def handle_params(
        %{"view" => "insights", "active_tab" => "scored_activities"} = _params,
        _uri,
        socket
      ) do
    socket = assign(socket, active_view: :scored_activities, active_tab: :scored_activities)
    {:noreply, socket}
  end

  def handle_params(
        %{"view" => "insights", "active_tab" => "practice_activities"} = _params,
        _uri,
        socket
      ) do
    socket = assign(socket, active_view: :practice_activities, active_tab: :practice_activities)
    {:noreply, socket}
  end

  def handle_params(%{"view" => "insights", "active_tab" => "surveys"} = _params, _uri, socket) do
    socket = assign(socket, active_view: :surveys, active_tab: :surveys)
    {:noreply, socket}
  end

  def handle_params(%{"view" => "manage"} = _params, _uri, socket) do
    socket = assign(socket, active_view: :manage, active_tab: :manage)
    {:noreply, socket}
  end

  def handle_params(%{"view" => "activity"} = _params, _uri, socket) do
    socket = assign(socket, active_view: :activity, active_tab: :activity)
    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    # socket = assign(socket, active_view: :students)
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
