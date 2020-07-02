defmodule OliWeb.Projects.Table do

  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes

  defp authors(assigns, project_id) do
    Map.get(assigns.authors, project_id)
  end

  def render(assigns) do
    ~L"""
    <table class="table table-hover table-bordered table-sm">
      <thead class="thead-dark">
        <tr><th>Title</th><th>Created</th><th>Authors</th></tr>
      </thead>
      <tbody>
        <%= for project <- @projects do %>
          <td><a href="<%= Routes.project_path(OliWeb.Endpoint, :overview, project) %>"><%= project.title %></td>
          <td><%= time(assigns, project.inserted_at) %></td>
          <td>
            <ul>
            <%= for author <- authors(assigns, project.id) do %>
              <li><%= author.last_name %>, <%= author.first_name %> (<%= author.email %>)</li>
            <% end %>
            </ul>
          </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp time(assigns, time) do
    ~L"""
    <span><%= Timex.format!(time, "{relative}", :relative)%></span>
    """
  end

end
