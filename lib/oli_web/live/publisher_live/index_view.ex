defmodule OliWeb.PublisherLive.IndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.PublisherLive.{NewView, TableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Inventories
  alias Surface.Components.Link

  data(title, :string, default: "Publishers")
  data(breadcrumbs, :any)

  data(filter, :any, default: %{})
  data(query, :string, default: "")
  data(total_count, :integer, default: 0)
  data(offset, :integer, default: 0)
  data(limit, :integer, default: 20)
  data(sort, :string, default: "sort")
  data(page_change, :string, default: "page_change")
  data(show_bottom_paging, :boolean, default: false)
  data(additional_table_class, :string, default: "")

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

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

  def mount(_, session, socket) do
    ctx = SessionContext.init_live(session)
    publishers = Inventories.list_publishers()

    {:ok, table_model} = TableModel.new(publishers, ctx)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(),
       publishers: publishers,
       table_model: table_model,
       total_count: length(publishers)
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

        <Link class="btn btn-primary" to={Routes.live_path(@socket, NewView)}>
          Create Publisher
        </Link>
      </div>

      <div id="publishers-table" class="p-4">
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
