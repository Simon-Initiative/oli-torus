defmodule OliWeb.Delivery.SelectSource do
  use OliWeb.Common.SortableTable.TableHandlers
  use Surface.LiveView

  alias Oli.Accounts
  alias Oli.Delivery
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Lti.LtiParams
  alias Oli.Publishing
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.Router.Helpers, as: Routes

  import Oli.Utils

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

  def breadcrumbs(:admin) do
    OliWeb.OpenAndFreeController.set_breadcrumbs() |> breadcrumb(:admin)
  end

  def breadcrumbs(:from_lms) do
    breadcrumb([
      Breadcrumb.new(%{
        full_title: "Create Course Section",
        link: Routes.delivery_path(OliWeb.Endpoint, :index)
      })
    ], :from_lms, "Quick Start")
  end

  def breadcrumbs(:independent_learner) do
    breadcrumb([
      Breadcrumb.new(%{
        full_title: "My Courses",
        link: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)
      })
    ], :independent_learner)
  end

  def breadcrumb(previous, type, title \\ "Select Source") do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: title,
          link: Routes.select_source_path(OliWeb.Endpoint, type)
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

          String.contains?(String.downcase(title), str)
        end)
    end
  end

  def live_path(socket, params),
    do: Routes.select_source_path(socket, socket.assigns.live_action, params)

  def mount(_params, session, socket) do
    # SelectSource used in three routes.
    # live_action is :independent_learner, :admin or :from_lms
    route = socket.assigns.live_action

    lti_params =
      case session["lti_params_id"] do
        nil ->
          nil

        lti_params_id ->
          %{params: lti_params} = LtiParams.get_lti_params(lti_params_id)
          lti_params
      end

    user =
      case session["current_user_id"] do
        nil -> nil
        current_user_id -> Accounts.get_user!(current_user_id, preload: [:author])
      end

    sources =
      retrieve_all_sources(route, %{user: user, lti_params: lti_params})
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

    {:ok, table_model} = OliWeb.Delivery.SelectSource.TableModel.new(sources)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs(route),
       delivery_breadcrumb: true,
       total_count: length(sources),
       table_model: table_model,
       sources: sources,
       user: user,
       lti_params: lti_params
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

  def handle_event("selected", %{"id" => source}, socket),
    do: handle_select(socket.assigns.live_action, source, socket)

  defp handle_select(:from_lms, source, socket) do
    case Delivery.create_section(
           source,
           socket.assigns.user,
           socket.assigns.lti_params
         ) do
      {:ok, _section} ->
        {:noreply,
         socket
         |> put_flash(:info, "Section successfully created.")
         |> push_redirect(to: Routes.delivery_path(OliWeb.Endpoint, :index))}

      {:error, error} ->
        {_error_id, error_msg} = log_error("Failed to create new section", error)
        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  defp handle_select(live_action, source, socket) do
    {:noreply,
     redirect(socket,
       to: OliWeb.OpenAndFreeView.get_path([live_action, :new, %{"source_id" => source}])
     )}
  end

  defp retrieve_all_sources(:admin, _opts) do
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

  defp retrieve_all_sources(:independent_learner, %{user: user}),
    do: Publishing.retrieve_visible_sources(user, nil)

  defp retrieve_all_sources(:from_lms, %{user: user, lti_params: lti_params}),
    do: Delivery.retrieve_visible_sources(user, lti_params)
end
