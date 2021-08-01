defmodule OliWeb.Breadcrumb.BreadcrumbTrailLive do
  use Phoenix.LiveView
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Course
  alias OliWeb.Breadcrumb.BreadcrumbLive
  alias OliWeb.Common.Breadcrumb
  alias Oli.Publishing.AuthoringResolver

  def mount(
        _params,
        %{
          "project_slug" => project_slug,
          "container_slug" => container_slug,
          "breadcrumbs" => breadcrumbs
        },
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)

    {:ok,
     assign(socket,
       project: project,
       container_slug: container_slug,
       breadcrumbs: breadcrumbs
     )}
  end

  def render(assigns) do
    ~L"""
    <nav aria-label="breadcrumb overflow-hidden">
      <ol class="breadcrumb custom-breadcrumb">

        <%= live_component BreadcrumbLive,
          id: "breadcrumb-project",
          breadcrumb: Breadcrumb.new(%{
            full_title: @project.title,
            link: Routes.container_path(@socket, :index, @project.slug, AuthoringResolver.root_container(@project.slug).slug)
          }),
          is_last: false,
          show_short: false
        %>

        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <%= live_component BreadcrumbLive,
            id: "breadcrumb-#{index}",
            breadcrumb: breadcrumb,
            project: @project,
            container_slug: @container_slug,
            is_last: length(@breadcrumbs) - 1 == index,
            show_short: length(@breadcrumbs) > 3
          %>
        <% end %>
      </ol>
    </nav>
    """
  end
end
