defmodule OliWeb.CommunityLive.Associated.IndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.CommunityLive.ShowView
  alias OliWeb.CommunityLive.Associated.{NewView, TableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}

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

  def mount(%{"community_id" => community_id}, session, socket) do
    ctx = SessionContext.init(socket, session)

    associations = Groups.list_community_visibilities(community_id)
    {:ok, table_model} = TableModel.new(associations, ctx, :id, "remove")

    {:ok,
     assign(socket,
       ctx: ctx,
       breadcrumbs: breadcrumb(community_id),
       associations: associations,
       community_id: community_id,
       table_model: table_model,
       total_count: length(associations),
       limit: 20
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="d-flex p-3 justify-content-between">
      <Filter.render change="change_search" reset="reset_search" apply="apply_search" query={@query} />

      <.link class="btn btn-primary" href={Routes.live_path(OliWeb.Endpoint, NewView, @community_id)}>
        Add new +
      </.link>
    </div>

    <div id="projects-products-table" class="p-4">
      <Listing.render
        filter={@query}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"
        show_bottom_paging={false}
        additional_table_class=""
      />
    </div>
    """
  end

  def handle_event("remove", %{"id" => id}, socket) do
    clear_flash(socket)

    case Groups.delete_community_visibility(id) do
      {:ok, _community_visibility} ->
        associations = Groups.list_community_visibilities(socket.assigns.community_id)
        {:ok, table_model} = TableModel.new(associations, socket.assigns.ctx, :id, "remove")

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
