defmodule OliWeb.CollaborationLive.IndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Resources.Collaboration
  alias OliWeb.Admin.AdminView
  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.CollaborationLive.AdminTableModel
  alias OliWeb.Router.Helpers, as: Routes

  @title "Collaborative Spaces"

  data title, :string, default: @title
  data breadcrumbs, :any
  data filter, :any, default: %{}
  data query, :string, default: ""
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data sort, :string, default: "sort"
  data page_change, :string, default: "page_change"
  data show_bottom_paging, :boolean, default: false
  data additional_table_class, :string, default: ""

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.collab_spaces, fn cs ->
      String.contains?(String.downcase(cs.page.title), query_str) or
        String.contains?(String.downcase(cs.project.title), query_str)
    end)
  end

  def live_path(socket, params) do
    Routes.collab_spaces_index_path(socket, socket.assigns.live_action, params)
  end

  def breadcrumb(:admin) do
    AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: Routes.collab_spaces_index_path(OliWeb.Endpoint, :admin)
        })
      ]
  end

  def mount(_, session, socket) do
    live_action = socket.assigns.live_action
    context = SessionContext.init(session)

    collab_spaces = Collaboration.list_collaborative_spaces()
    {:ok, table_model} = AdminTableModel.new(collab_spaces, context)

    {:ok,
      assign(socket,
        breadcrumbs: breadcrumb(live_action),
        collab_spaces: collab_spaces,
        table_model: table_model,
        total_count: length(collab_spaces)
      )}
  end

  def render(assigns) do
    ~F"""
      <div class="d-flex p-3 justify-content-between">
        <Filter
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}/>
      </div>

      <div id="collaborative-spaces-table" class="p-4">
        <Listing
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort={@sort}
          page_change={@page_change}
          show_bottom_paging={@show_bottom_paging}
          additional_table_class={@additional_table_class}/>
      </div>
    """
  end
end
