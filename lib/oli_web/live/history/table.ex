defmodule OliWeb.RevisionHistory.Table do
  use Phoenix.LiveComponent


  defp publication_state(assigns, revision_id) do

    publication = assigns.publication

    case Map.get(assigns.mappings, revision_id) do

      %{publication: ^publication} ->
        ~L"""
        <span class="badge badge-success">Currently Published</span>
        """

      %{publication: %{published: true}} ->
        ~L"""
        <span class="badge badge-info">Previously Published</span>
        """

      _ ->
        ~L"""
        <span></span>
        """
    end
  end

  defp time(assigns, time) do
    ~L"""
    <span><%= Timex.format!(time, "{relative}", :relative)%></span>
    """
  end

  def render(assigns) do

    range = Range.new(assigns.page_offset, assigns.page_offset + assigns.page_size)
    to_display = Enum.slice(assigns.revisions, range)

    ~L"""
    <table class="table table-hover table-bordered table-sm">
      <thead class="thead-dark">
        <tr><th>Id</th><th>Created</th><th>Updated</th><th>Author</th><th>Slug</th><th>Published</th></tr>
      </thead>
      <tbody id="revisions">
      <%= for rev <- to_display do %>
        <%= if rev == @selected do %>
        <tr id="<%= rev.id %>" class="table-active">
        <% else %>
        <tr id="<%= rev.id %>" style="cursor: pointer;" phx-click="select" phx-value-rev="<%= rev.id %>">
        <% end %>
        <td><%= rev.id %></td>
        <td><%= time(assigns, rev.inserted_at) %></td>
        <td><%= time(assigns, rev.updated_at) %></td>
        <td><%= rev.author_id %></td>
        <td><%= rev.slug %></td>
        <td><%= publication_state(assigns, rev.id) %></td>
        </tr>
      <% end %>
      </tbody>
    </table>
    """
  end
end
