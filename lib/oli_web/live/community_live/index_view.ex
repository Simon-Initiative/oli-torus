defmodule OliWeb.CommunityLive.IndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Accounts
  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.CommunityLive.{NewView, TableModel}
  alias OliWeb.Router.Helpers, as: Routes

  alias Phoenix.LiveView.JS

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def filter_rows(socket, query, filter) do
    query_str = String.downcase(query)
    status_list = withelist_filter(filter, "status", ["active", "deleted"])

    Enum.filter(socket.assigns.communities, fn c ->
      String.contains?(String.downcase(c.name), query_str) and
        Atom.to_string(c.status) in status_list
    end)
  end

  def live_path(socket, params) do
    Routes.live_path(socket, __MODULE__, params)
  end

  def breadcrumb() do
    [
      Breadcrumb.new(%{
        full_title: "Communities",
        link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
      })
    ]
  end

  def mount(
        _,
        _session,
        socket
      ) do
    is_admin = socket.assigns.is_admin

    communities =
      if is_admin do
        Groups.list_communities()
      else
        Accounts.list_admin_communities(socket.assigns.current_author.id)
      end

    ctx = socket.assigns.ctx

    {:ok, table_model} = TableModel.new(communities, ctx)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(),
       communities: communities,
       table_model: table_model,
       total_count: length(communities),
       is_admin: is_admin,
       limit: 20,
       offset: 0,
       filter: %{"status" => "active"},
       query: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="d-flex p-3 justify-content-between">
      <Filter.render change="change_search" reset="reset_search" apply="apply_search" query={@query} />

      <.link :if={@is_admin} class="btn btn-primary" href={Routes.live_path(@socket, NewView)}>
        Create Community
      </.link>
    </div>
    <div id="community-filters" class="p-3">
      <.form for={%{}} phx-change="apply_filter" class="pl-4">
        <div class="form-group">
          <.input
            type="checkbox"
            phx-click={
              JS.push("apply_filter",
                value: %{
                  filter: %{
                    status:
                      if(Map.get(@filter, "status") == "active", do: "active,deleted", else: "active")
                  }
                }
              )
            }
            name={:status}
            value="true"
            checked={Map.get(@filter, "status", "active") == "active"}
            class="form-check-input"
            label="Show only active communities"
          />
        </div>
      </.form>
    </div>

    <div id="communities-table" class="p-4">
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
    """
  end
end
