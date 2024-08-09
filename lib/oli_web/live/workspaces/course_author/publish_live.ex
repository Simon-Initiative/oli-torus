defmodule OliWeb.Workspaces.CourseAuthor.PublishLive do
  use OliWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project

    {:ok,
     assign(socket,
       project_slug: project.slug,
       project_title: project.title,
       active_workspace: :course_author,
       active_view: :publish
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1 class="flex flex-col w-full h-screen items-center justify-center">
      Placeholder for Publish
    </h1>
    """
  end
end
