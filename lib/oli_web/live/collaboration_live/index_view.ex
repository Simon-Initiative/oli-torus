defmodule OliWeb.CollaborationLive.IndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Resources.Collaboration
  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.CollaborationLive.InstructorTableModel
  alias alias OliWeb.Sections.Mount

  @title "Collaborative Spaces"

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.collab_spaces, fn cs ->
      String.contains?(String.downcase(cs.page.title), query_str)
    end)
  end

  def live_path(
        %{assigns: %{section_slug: section_slug}} = _socket,
        params
      ),
      do: ~p"/sections/#{section_slug}/collaborative_spaces?#{params}"

  def breadcrumb(section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(:instructor, section) ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: ~p"/sections/#{section.slug}/collaborative_spaces"
        })
      ]
  end

  def mount(params, session, socket) do
    ctx = SessionContext.init(socket, session)
    section_slug = params["section_slug"]

    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_type, _user, _section} ->
        {collab_spaces, table_model} =
          get_collab_spaces_and_table_model(ctx, section_slug)

        {:ok,
         assign(socket,
           breadcrumbs: breadcrumb(socket.assigns[:section]),
           section_slug: section_slug,
           collab_spaces: collab_spaces,
           table_model: table_model,
           total_count: length(collab_spaces),
           limit: 20,
           offset: 0,
           query: ""
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <div class="d-flex p-3 justify-content-between">
        <Filter.render
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}
        />
      </div>

      <div id="collaborative-spaces-table" class="p-4">
        <Listing.render
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort="sort"
          page_change="page_change"
          show_bottom_paging={false}
        />
      </div>
    </div>
    """
  end

  defp get_collab_spaces_and_table_model(ctx, section_slug) do
    {_, collab_spaces} = Collaboration.list_collaborative_spaces_in_section(section_slug)
    {:ok, table_model} = InstructorTableModel.new(collab_spaces, ctx)

    {collab_spaces, table_model}
  end
end
