defmodule OliWeb.RevisionHistory.Table do
  use OliWeb, :surface_component

  prop selected, :string
  prop revisions, :any
  prop publication, :any
  prop mappings, :any
  prop tree, :any
  prop page_offset, :number
  prop page_size, :number

  defp publication_state(assigns, revision_id) do
    publication = assigns.publication

    case Map.get(assigns.mappings, revision_id) do
      %{publication: ^publication} ->
        ~F"""
        <span class="badge badge-success">Currently Published</span>
        """

      %{publication: %{published: published}} when not is_nil(published) ->
        ~F"""
        <span class="badge badge-info">Previously Published</span>
        """

      _ ->
        ~F"""
        <span></span>
        """
    end
  end

  def render(assigns) do
    range = Range.new(assigns.page_offset, assigns.page_offset + assigns.page_size)
    to_display = Enum.slice(assigns.revisions, range)

    tr_props = fn rev_id ->
      if rev_id == assigns.selected.id do
        [class: "table-active"]
      else
        [style: "cursor: pointer;", "phx-click": "select", "phx-value-rev": rev_id]
      end
    end

    ~F"""
    <table class="table table-hover table-bordered table-sm">
      <thead class="thead-dark">
        <tr><th>Id</th><th>Project</th><th>Created</th><th>Updated</th><th>Author</th><th>Slug</th><th>Published</th></tr>
      </thead>
      <tbody id="revisions">
      {#for rev <- to_display }
        <tr id="{ rev.id }" {...tr_props.(rev.id)}>
          <td>{ rev.id }</td>
          <td>{ Map.get(@tree, rev.id).project_id }</td>
          <td>{ date(rev.inserted_at) }</td>
          <td>{ date(rev.updated_at) }</td>
          <td>{ rev.author.email }</td>
          <td>{ rev.slug }</td>
          <td>{ publication_state(assigns, rev.id) }</td>
        </tr>
      {/for}
      </tbody>
    </table>
    """
  end
end
