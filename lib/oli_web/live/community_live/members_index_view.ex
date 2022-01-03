defmodule OliWeb.CommunityLive.MembersIndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.CommunityLive.{ShowView, MembersTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Community Members"
  data breadcrumbs, :any

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
    Enum.filter(socket.assigns.members, fn m ->
      String.contains?(String.downcase(m.name), String.downcase(query)) or
        String.contains?(String.downcase(m.email), String.downcase(query))
    end)
  end

  def live_path(socket, params) do
    Routes.live_path(socket, __MODULE__, socket.assigns.community_id, params)
  end

  def breadcrumb(community_id) do
    ShowView.breadcrumb(community_id) ++
      [
        Breadcrumb.new(%{
          full_title: "Members",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, community_id)
        })
      ]
  end

  def mount(%{"community_id" => community_id}, _session, socket) do
    members = Groups.list_community_members(community_id)
    {:ok, table_model} = MembersTableModel.new(members)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(community_id),
       members: members,
       community_id: community_id,
       table_model: table_model,
       total_count: length(members)
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

      <div class="p-4">
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

  def handle_event("remove", %{"id" => id}, socket) do
    socket = clear_flash(socket)

    case Groups.delete_community_account(%{
           community_id: socket.assigns.community_id,
           user_id: id
         }) do
      {:ok, _community_account} ->
        members = Groups.list_community_members(socket.assigns.community_id)
        {:ok, table_model} = MembersTableModel.new(members)

        socket =
          put_flash(socket, :info, "Community member successfully removed.")
          |> assign(
            members: members,
            table_model: table_model,
            total_count: length(members)
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

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Community member couldn't be removed.")}
    end
  end
end
