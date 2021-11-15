defmodule OliWeb.Delivery.SelectSource do
  use Surface.LiveView

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Filter
  alias OliWeb.Common.Listing
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
  data query, :string, default: ""
  data applied_query, :string, default: ""

  @table_filter_fn &OliWeb.Delivery.SelectSource.filter_rows/3
  @table_push_patch_path &OliWeb.Delivery.SelectSource.live_path/2

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Select Source",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def filter_rows(socket, query, _filter) do
    case String.downcase(query) do
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

    free_project_publications =
      Oli.Publishing.all_available_publications()
      |> then(fn publications ->
        Blueprint.filter_for_free_projects(
          products,
          publications
        )
      end)

    free_project_publications ++ products
  end

  def mount(_, _, socket) do
    sources =
      retrieve_all_sources()
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

    total_count = length(sources)

    {:ok, table_model} = OliWeb.Delivery.SelectSource.TableModel.new(sources)

    {:ok,
     assign(socket,
       breadcrumbs: OliWeb.OpenAndFreeController.set_breadcrumbs() |> breadcrumb(),
       total_count: total_count,
       table_model: table_model,
       sources: sources
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <Filter apply={"apply_search"} change={"change_search"} reset="reset_search"/>

      <div class="mb-3"/>

      <Listing
        filter={@applied_query}
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
