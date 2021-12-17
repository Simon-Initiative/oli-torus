defmodule OliWeb.RevisionHistory.Table do
  use OliWeb, :live_component

  defp publication_state(assigns, revision_id) do
    publication = assigns.publication

    case Map.get(assigns.mappings, revision_id) do
      %{publication: ^publication} ->
        ~L"""
        <span class="badge badge-success">Currently Published</span>
        """

      %{publication: %{published: published}} when not is_nil(published) ->
        ~L"""
        <span class="badge badge-info">Previously Published</span>
        """

      _ ->
        ~L"""
        <span></span>
        """
    end
  end

  def render(assigns) do
    range = Range.new(assigns.page_offset, assigns.page_offset + assigns.page_size)
    to_display = Enum.slice(assigns.revisions, range)

    ~L"""
    <table class="table table-hover table-bordered table-sm">
      <thead class="thead-dark">
        <tr><th>Id</th><th>Project</th><th>Created</th><th>Updated</th><th>Author</th><th>Slug</th><th>Published</th></tr>
      </thead>
      <tbody id="revisions">
      <%= for rev <- to_display do %>
        <%= if rev.id == @selected.id do %>
        <tr id="<%= rev.id %>" class="table-active">
        <% else %>
        <tr id="<%= rev.id %>" style="cursor: pointer;" phx-click="select" phx-value-rev="<%= rev.id %>">
        <% end %>
        <td><%= rev.id %></td>
        <td><%= Map.get(assigns.tree, rev.id).project_id %></td>
        <td><%= date(rev.inserted_at) %></td>
        <td><%= date(rev.updated_at) %></td>
        <td><%= rev.author.email %></td>
        <td><%= rev.slug %></td>
        <td><%= publication_state(assigns, rev.id) %></td>
        </tr>
      <% end %>
      </tbody>
    </table>
    """
  end
end
