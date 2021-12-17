defmodule OliWeb.CommunityLive.Associated.IndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.CommunityLive.ShowView
  alias OliWeb.CommunityLive.Associated.{NewView, TableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Link

  data title, :string, default: "Community Associated"
  data breadcrumbs, :any

  data query, :string, default: ""
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data sort, :string, default: "sort"
  data page_change, :string, default: "page_change"

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, query, _filter) do
    Enum.filter(socket.assigns.associations, fn a ->
      String.contains?(String.downcase(TableModel.get_field(:title, a)), String.downcase(query))
    end)
  end

  def live_path(socket, params) do
    Routes.live_path(socket, __MODULE__, socket.assigns.community_id, params)
  end

  def breadcrumb(community_id) do
    ShowView.breadcrumb(community_id) ++
      [
        Breadcrumb.new(%{
          full_title: "Associated",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, community_id)
        })
      ]
  end

  def mount(%{"community_id" => community_id}, _session, socket) do
    associations = Groups.list_community_visibilities(community_id)
    {:ok, table_model} = TableModel.new(associations, :id, "remove")

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(community_id),
       associations: associations,
       community_id: community_id,
       table_model: table_model,
       total_count: length(associations)
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

        <Link class="btn btn-primary" to={Routes.live_path(@socket, NewView, @community_id)}>
          Add new +
        </Link>
      </div>

      <div id="projects-products-table" class="p-4">
        <Listing
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort={@sort}
          page_change={@page_change}
          show_bottom_paging={false}
          additional_table_class=""/>
      </div>
    """
  end

  def handle_event("remove", %{"id" => id}, socket) do
    clear_flash(socket)

    case Groups.delete_community_visibility(id) do
      {:ok, _community_visibility} ->
        associations = Groups.list_community_visibilities(socket.assigns.community_id)
        {:ok, table_model} = TableModel.new(associations, :id, "remove")

        socket =
          put_flash(socket, :info, "Association successfully removed.")
          |> assign(
            associations: associations,
            table_model: table_model,
            total_count: length(associations)
          )

        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 socket.assigns.offset,
                 socket.assigns.query,
                 socket.assigns.filter
               )
             ),
           replace: true
         )}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Coludn't remove association."
         )}
    end
  end
end
