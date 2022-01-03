defmodule OliWeb.CommunityLive.Associated.NewView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Authoring.Course
  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.CommunityLive.Associated.{IndexView, TableModel}
  alias Oli.Delivery.Sections.Blueprint
  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Community Associate New"
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
    Enum.filter(socket.assigns.sources, fn a ->
      String.contains?(String.downcase(TableModel.get_field(:title, a)), String.downcase(query))
    end)
  end

  def live_path(socket, params) do
    Routes.live_path(socket, __MODULE__, socket.assigns.community_id, params)
  end

  def breadcrumb(community_id) do
    IndexView.breadcrumb(community_id) ++
      [
        Breadcrumb.new(%{
          full_title: "New",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, community_id)
        })
      ]
  end

  defp retrieve_all_sources(community_id) do
    (Course.list_projects_not_in_community(community_id) ++
       Blueprint.list_products_not_in_community(community_id))
    |> Enum.with_index(fn element, index ->
      type =
        case Map.has_key?(element, :type) and Map.get(element, :type) == :blueprint do
          true -> "product"
          _ -> "project"
        end

      Map.merge(element, %{
        unique_type: type,
        unique_id: index
      })
    end)
  end

  def mount(%{"community_id" => community_id}, _session, socket) do
    sources = retrieve_all_sources(community_id)
    {:ok, table_model} = TableModel.new(sources)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb(community_id),
       sources: sources,
       table_model: table_model,
       total_count: length(sources),
       community_id: community_id
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="p-3">
        <Filter
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}/>
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

  def handle_event("select", %{"id" => id, "type" => type}, socket) do
    clear_flash(socket)

    attrs =
      Map.merge(
        %{
          community_id: socket.assigns.community_id
        },
        case type do
          "product" -> %{section_id: id}
          "project" -> %{project_id: id}
        end
      )

    case Groups.create_community_visibility(attrs) do
      {:ok, _community_visibility} ->
        sources = retrieve_all_sources(socket.assigns.community_id)
        {:ok, table_model} = TableModel.new(sources)

        socket =
          put_flash(socket, :info, "Association to #{type} successfully added.")
          |> assign(
            sources: sources,
            table_model: table_model,
            total_count: length(sources)
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
           "Couldn't associate #{type}. Already exists or an unexpected error ocurred."
         )}
    end
  end
end
