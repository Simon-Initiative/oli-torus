defmodule OliWeb.Breadcrumb.BreadcrumbTrailLive do
  use Phoenix.LiveView
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Course
  alias OliWeb.Breadcrumb.BreadcrumbLive
  alias OliWeb.Common.Breadcrumb

  def mount(
        _params,
        %{
          "breadcrumbs" => breadcrumbs
        } = session,
        socket
      ) do
    project =
      case Map.get(session, "project_slug") do
        nil -> nil
        project_slug -> Course.get_project_by_slug(project_slug)
      end

    {:ok,
     assign(socket,
       project: project,
       breadcrumbs: breadcrumbs
     )}
  end

  def render(assigns) do
    ~L"""
    <nav aria-label="breadcrumb overflow-hidden">
      <ol class="breadcrumb custom-breadcrumb">

        <%= if !is_nil(@project) do %>
          <%= live_component BreadcrumbLive,
            id: "breadcrumb-project",
            breadcrumb: Breadcrumb.new(%{
              full_title: @project.title,
              link: Routes.project_path(@socket, :overview, @project)
            }),
            is_last: false,
            show_short: false
          %>
        <% end %>

        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <%= live_component BreadcrumbLive,
            id: "breadcrumb-#{index}",
            breadcrumb: breadcrumb,
            is_last: length(@breadcrumbs) - 1 == index,
            show_short: length(@breadcrumbs) > 3
          %>
        <% end %>
      </ol>
    </nav>
    """
  end
end
