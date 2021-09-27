defmodule OliWeb.Delivery.SelectSource do
  use Surface.LiveView
  alias Oli.Repo

  alias OliWeb.Products.Filter
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Sections.Blueprint
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any,
    default: [Breadcrumb.new(%{full_title: "Select Source for New Section"})]

  data title, :string, default: "Select Source for New Section"

  data sources, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data filter, :string, default: ""

  defp retrieve_all_sources() do
    products = Blueprint.list()
    publications = Oli.Publishing.all_publications()

    filtered =
      Enum.filter(publications, fn p -> p.published end)
      |> then(fn publications ->
        Blueprint.filter_for_free_projects(
          products,
          publications
        )
      end)

    filtered ++ products
  end

  def mount(_, _, socket) do
    sources =
      retrieve_all_sources()
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

    total_count = length(sources)

    {:ok, table_model} = OliWeb.Delivery.SelectSource.TableModel.new(sources)

    {:ok,
     assign(socket,
       total_count: total_count,
       table_model: table_model,
       sources: sources
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <Filter id="filter" change={"change_filter"} reset="reset_filter"/>

      <div class="mb-3"/>

      <Listing
        filter={@filter}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  def handle_event("change_filter", %{"text" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             socket.assigns.offset,
             filter
           )
         )
     )}
  end

  def handle_event("reset_filter", _, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             socket.assigns.offset,
             ""
           )
         )
     )}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             String.to_integer(offset),
             socket.assigns.filter
           )
         )
     )}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    table_model =
      SortableTableModel.update_sort_params(
        socket.assigns.table_model,
        String.to_existing_atom(sort_by)
      )

    offset = socket.assigns.offset

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(table_model, offset, socket.assigns.filter)
         )
     )}
  end

  defp get_patch_params(table_model, offset, filter) do
    Map.merge(%{offset: offset, filter: filter}, SortableTableModel.to_params(table_model))
  end

  def handle_params(params, _, socket) do
    offset = get_int_param(params, "offset", 0)

    # Ensure that the offset is 0 or one minus a factor of the limit. So for a
    # limit of 20, valid offsets or 0, 20, 40, etc.  This logic overrides any attempt
    # to manually change URL offset param.
    offset =
      case rem(offset, socket.assigns.limit) do
        0 -> offset
        _ -> 0
      end

    filter = get_str_param(params, "filter", "")

    # First update the rows of the sortable table model to be all products, then apply the sort,
    # then slice the model rows according to the paging settings

    filtered =
      case String.downcase(filter) do
        "" ->
          socket.assigns.sources

        str ->
          Enum.filter(socket.assigns.sources, fn p ->
            title =
              case Map.get(p, :type) do
                nil -> p.project.title
                :blueprint -> p.title
              end

            String.downcase(title)
            |> String.contains?(str)
          end)
      end

    table_model =
      Map.put(socket.assigns.table_model, :rows, filtered)
      |> SortableTableModel.update_from_params(params)
      |> then(fn table_model ->
        Map.put(table_model, :rows, Enum.slice(table_model.rows, offset, socket.assigns.limit))
      end)

    {:noreply,
     assign(socket,
       table_model: table_model,
       offset: offset,
       filter: filter,
       total_count: length(filtered)
     )}
  end

  defp get_int_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        case Integer.parse(value) do
          {num, _} -> num
          _ -> default_value
        end
    end
  end

  defp get_str_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        value
    end
  end
end
