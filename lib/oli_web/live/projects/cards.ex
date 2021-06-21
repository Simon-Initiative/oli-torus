defmodule OliWeb.Projects.Cards do
  alias OliWeb.Projects.Card
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
    <div class="container">
      <div class="row">
        <div class="col-12">
          <%= if length(@projects) == 0 do %>
            <small>No projects yet</small>
            <p>Create a new project to get started, or ask a friend to invite you to their project.</p>
          <% else %>
            <div class="row row-cols-1 row-cols-sm-2 row-cols-md-2 row-cols-lg-3 g-4">
              <%= for project <- @projects do %>
                <%= live_component Card, project: project, author_count: length(Map.get(@authors, project.id)) %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
