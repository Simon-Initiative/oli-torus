defmodule OliWeb.Workspaces.CourseAuthor.PagesLive do
  use OliWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h1>
      Placeholder for All Pages
    </h1>
    """
  end
end
