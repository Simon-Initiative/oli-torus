defmodule OliWeb.CommunityLive.MembersIndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.CommunityLive.{ShowView, MembersTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}

  def filter_rows(socket, query, _filter) do
    Enum.filter(socket.assigns.members, &member_filter(&1.name, &1.email, query))
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
       total_count: length(members),
       offset: 0,
       limit: 20,
       query: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="d-flex p-3 justify-content-between">
      <Filter.render change="change_search" reset="reset_search" apply="apply_search" query={@query} />
    </div>

    <div class="p-4">
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

  defp member_filter(nil, email, query),
    do: String.contains?(String.downcase(email), String.downcase(query))

  defp member_filter(name, email, query) do
    String.contains?(String.downcase(name), String.downcase(query)) or
      String.contains?(String.downcase(email), String.downcase(query))
  end
end
