defmodule OliWeb.Delivery.SelectSource do
  use Surface.LiveView

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Products.Filter
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Sections.Blueprint

  data breadcrumbs, :any,
    default: [Breadcrumb.new(%{full_title: "Select Source for New Section"})]

  data title, :string, default: "Select Source for New Section"

  data sources, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data filter, :string, default: ""
  data applied_filter, :string, default: ""

  @table_filter_fn &OliWeb.Delivery.SelectSource.filter_rows/2
  @table_push_patch_path &OliWeb.Delivery.SelectSource.live_path/2

  def filter_rows(socket, filter) do
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
  end

  def live_path(socket, params) do
    Routes.live_path(socket, OliWeb.Delivery.SelectSource, params)
  end

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

      <Filter apply={"apply_filter"} change={"change_filter"} reset="reset_filter"/>

      <div class="mb-3"/>

      <Listing
        filter={@applied_filter}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  def handle_event("selected", %{"id" => source}, socket) do
    path =
      Routes.open_and_free_path(
        OliWeb.Endpoint,
        :new,
        %{"source_id" => source}
      )

    {:noreply,
     redirect(socket,
       to: path
     )}
  end

  use OliWeb.Common.SortableTable.TableHandlers
end
