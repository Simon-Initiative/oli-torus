defmodule OliWeb.Projects.Card do

  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~L"""
    <a href="<%= Routes.project_path(OliWeb.Endpoint, :overview, @project)%>" class="card-link">
      <div class="card-link">
        <h1><%= @project.title  %></h1>
        <p><%= @project.description %></p>
        <span class="authors"><%= @author_count %> <i class="material-icons-outlined">person</i>
      </div>
    </a>
    """
  end
end
