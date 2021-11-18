defmodule OliWeb.Delivery.SelectSource do
  use Surface.LiveView

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Products.Filter
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Accounts
  alias Oli.Institutions.Institution

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

  # Breadcrumbs are an authoring-only requirement.
  # SelectSource is used in delivery section creation (for LMS-lite functionality),
  # so no breadcrumbs are needed in that context.
  def breadcrumbs(:admin) do
    OliWeb.OpenAndFreeController.set_breadcrumbs() |> breadcrumb()
  end

  def breadcrumbs(_), do: []

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Select Source",
          link: Routes.select_source_path(OliWeb.Endpoint, :admin)
        })
      ]
  end

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
    Routes.select_source_path(socket, socket.assigns.live_action, params)
  end

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    # SelectSource used in two routes.
    # live_action is :independent_learner or :admin
    route = socket.assigns.live_action

    sources =
      retrieve_all_sources(route, user_id)
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

    total_count = length(sources)

    {:ok, table_model} = OliWeb.Delivery.SelectSource.TableModel.new(sources)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs(route),
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
      OliWeb.OpenAndFreeView.get_path([socket.assigns.live_action, :new, %{"source_id" => source}])

    {:noreply,
     redirect(socket,
       to: path
     )}
  end

  use OliWeb.Common.SortableTable.TableHandlers

  defp retrieve_all_sources(route, user_id) do
    author =
      user_id
      |> Accounts.get_user!(preload: [:author])
      |> Map.get(:author)

    IO.inspect(Accounts.get_user!(user_id, preload: [:author]), label: "Author")
    IO.inspect(route, label: "route")

    products = get_products(route, author)

    project_publications = get_publications(route, author, products)

    project_publications ++ products
  end

  defp get_products(:admin, _author), do: Blueprint.list()

  defp get_products(:independent_learner, author) do
    Blueprint.available_products(author, empty_institution())
  end

  # Admins filter to free pubs
  defp get_publications(:admin, _author, products),
    do:
      Oli.Publishing.all_available_publications()
      |> then(fn publications ->
        Blueprint.filter_for_free_projects(
          products,
          publications
        )
      end)

  defp get_publications(:independent_learner, author, _products),
    do: Oli.Publishing.available_publications(author, empty_institution())

  defp empty_institution(),
    do: %Institution{
      id: "invalid id used only to fulfill query requirement"
    }
end
