defmodule OliWeb.Projects.Card do

  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~L"""
    <a href="<%= Routes.project_path(OliWeb.Endpoint, :overview, @project)%>" class="project-card-link">
      <div class="project-card">
        <h1><%= @project.title %></h1>
        <p class="project-description"><%= @project.description %></p>
        <span class="authors"><%= @author_count %> <i class="material-icons-outlined">person</i>
      </div>
    </a>
    """
  end
end
