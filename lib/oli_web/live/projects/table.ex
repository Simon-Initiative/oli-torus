defmodule OliWeb.Projects.Table do
  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes

  defp authors(assigns, project_id) do
    Map.get(assigns.authors, project_id)
  end

  def th(assigns, label, sort_by, sort_order, column) do
    ~L"""
    <th style="cursor: pointer;" phx-click="sort" phx-value-sort_by="<%= column %>">
      <%= label %>
      <%= if sort_by == column do %>
        <i class="fas fa-sort-<%= if sort_order == "asc" do "up" else "down" end %>"></i>
      <% end %>
    </th>
    """
  end

  def render(assigns) do
    ~L"""
    <table class="table table-striped table-bordered">
      <thead>
        <tr>
          <%= th(assigns, "Title", @sort_by, @sort_order, "title") %>
          <%= th(assigns, "Created", @sort_by, @sort_order, "created") %>
          <%= th(assigns, "Collaborators", @sort_by, @sort_order, "author") %>
          <%= if @is_admin do %>
            <%= th(assigns, "Status", @sort_by, @sort_order, "status") %>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for project <- @projects do %>
          <tr>
          <td>
            <%= if project.status == :deleted do %>
              <span><%= project.title %></span>
            <% else %>
              <a href="<%= Routes.project_path(OliWeb.Endpoint, :overview, project) %>"><%= project.title %></a>
            <% end %>
          </td>
          <td><%= time_ago(assigns, project.inserted_at) %></td>
          <td>
            <ul>
            <%= for author <- authors(assigns, project.id) do %>
              <li><%= author.name %> (<%= author.email %>)</li>
            <% end %>
            </ul>
          </td>
          <%= if @is_admin do %>
            <td>
              <%= if project.status == :deleted do %>
                <span class="text-danger">Deleted</span>
              <% else %>
                <span class="text-success">Active</span>
              <% end %>
            </td>
          <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  def time_ago(assigns, time) do
    ~L"""
    <span><%= Timex.format!(time, "{relative}", :relative)%></span>
    """
  end
end
