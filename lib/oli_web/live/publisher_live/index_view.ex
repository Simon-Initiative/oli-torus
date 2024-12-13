defmodule OliWeb.PublisherLive.IndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Inventories
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.PublisherLive.{NewView, TableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.publishers, fn p ->
      String.contains?(String.downcase(p.name), query_str)
    end)
  end

  def live_path(socket, params) do
    Routes.live_path(socket, __MODULE__, params)
  end

  def breadcrumb() do
    [
      Breadcrumb.new(%{
        full_title: "Publishers",
        link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
      })
    ]
  end

  def mount(_, _session, socket) do
    ctx = socket.assigns.ctx
    publishers = Inventories.list_publishers()

    {:ok, table_model} = TableModel.new(publishers, ctx)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(),
       publishers: publishers,
       table_model: table_model,
       total_count: length(publishers),
       limit: 20
     )}
  end

  attr :additional_table_class, :string, default: ""
  attr :breadcrumbs, :any
  attr :filter, :any, default: %{}
  attr :limit, :integer, default: 20
  attr :offset, :integer, default: 0
  attr :page_change, :string, default: "page_change"
  attr :query, :string, default: ""
  attr :show_bottom_paging, :boolean, default: false
  attr :sort, :string, default: "sort"
  attr :title, :string, default: "Publishers"
  attr :total_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="d-flex p-3 justify-content-between">
      <Filter.render change="change_search" reset="reset_search" apply="apply_search" query={@query} />

      <.link class="btn btn-primary" href={Routes.live_path(@socket, NewView)}>
        Create Publisher
      </.link>
    </div>

    <div id="publishers-table" class="p-4">
      <Listing.render
        filter={@query}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort={@sort}
        page_change={@page_change}
        show_bottom_paging={@show_bottom_paging}
        additional_table_class={@additional_table_class}
      />
    </div>
    """
  end
end
