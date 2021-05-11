defmodule OliWeb.Projects.Card do
  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~L"""
    <div class="col my-1">
      <a class="course-card-link card h-100 mb-4" href="<%= Routes.project_path(OliWeb.Endpoint, :overview, @project)%>">
        <div class="card-body">
          <h5 class="card-title"><%= @project.title  %></h5>
          <div class="d-flex justify-content-between align-items-center">
            <p class="card-text"><%= @project.description %></p>
            <span class="authors d-flex align-items-center"><%= @author_count %> <i class="material-icons-outlined">person</i>
          </div>
        </div>
      </a>
    </div>
    """
  end
end
