defmodule OliWeb.Breadcrumb.BreadcrumbTrailLive do
  use Phoenix.LiveView
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Course
  alias OliWeb.Breadcrumb.{BreadcrumbProvider, BreadcrumbLive}

  # Takes a list of BreadcrumbProviders, lays them out in a line, and delegates rendering/functionality to the breadcrumb (given the provider)
  def mount(
        _params,
        %{"project_slug" => project_slug, "breadcrumbs" => breadcrumbs},
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)

    {:ok,
     assign(socket,
       project: project,
       breadcrumbs: breadcrumbs
     )}
  end

  def render(assigns) do
    ~L"""
    <nav aria-label="breadcrumb">
      <ol class="breadcrumb custom-breadcrumb">

        <%= live_component @socket, BreadcrumbLive, breadcrumb: BreadcrumbProvider.new(%{
          full_title: @project.title,
          link: Routes.project_path(@socket, :overview, @project)}),
          last: false %>

        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <%= live_component @socket, BreadcrumbLive, breadcrumb: breadcrumb, last: length(@breadcrumbs) - 1 == index %>
        <% end %>
      </ol>
    </nav>
    """
  end
end
