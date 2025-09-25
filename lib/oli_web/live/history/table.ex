defmodule OliWeb.RevisionHistory.Table do
  use OliWeb, :html

  alias OliWeb.Common.Utils

  defp publication_state(assigns, revision_id) do
    publication = assigns.publication

    case Map.get(assigns.mappings, revision_id) do
      %{publication: ^publication} ->
        ~H"""
        <span class="badge badge-success">Currently Published</span>
        """

      %{publication: %{published: published}} when not is_nil(published) ->
        ~H"""
        <span class="badge badge-info">Previously Published</span>
        """

      _ ->
        ~H"""
        <span></span>
        """
    end
  end

  attr(:id, :string)
  attr(:selected, :string)
  attr(:revisions, :any)
  attr(:publication, :any)
  attr(:mappings, :any)
  attr(:tree, :any)
  attr(:page_offset, :integer)
  attr(:page_size, :integer)
  attr(:ctx, :map)

  def render(assigns) do
    range = Range.new(assigns.page_offset, assigns.page_offset + assigns.page_size)
    to_display = Enum.slice(assigns.revisions, range)

    tr_props = fn rev_id ->
      selected_id = if assigns.selected, do: assigns.selected.id, else: nil

      if rev_id == selected_id do
        [class: "table-active"]
      else
        [style: "cursor: pointer;", "phx-click": "select", "phx-value-rev": rev_id]
      end
    end

    assigns = Map.merge(assigns, %{tr_props: tr_props, to_display: to_display})

    ~H"""
    <table class="table table-hover table-bordered table-sm">
      <thead class="thead-dark">
        <tr>
          <th>Id</th>
          <th>Project</th>
          <th>Created</th>
          <th>Updated</th>
          <th>Author</th>
          <th>Slug</th>
          <th>Published</th>
        </tr>
      </thead>
      <tbody id="revisions">
        <%= for rev <- @to_display do %>
          <tr id={"revision-#{rev.id}"} {@tr_props.(rev.id)}>
            <td>{rev.id}</td>
            <td>
              {case Map.get(@tree, rev.id) do
                %{project_id: project_id} -> project_id
                _ -> "Unknown"
              end}
            </td>
            <td>{Utils.render_date(rev, :inserted_at, @ctx)}</td>
            <td>{Utils.render_date(rev, :updated_at, @ctx)}</td>
            <td>{if rev.author, do: rev.author.email, else: "Unknown"}</td>
            <td>{rev.slug}</td>
            <td>{publication_state(assigns, rev.id)}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
