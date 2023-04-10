defmodule OliWeb.Delivery.SelectSource do
  use OliWeb.Common.SortableTable.TableHandlers
  use Surface.LiveView

  alias Oli.Accounts
  alias Oli.Delivery
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Lti.LtiParams
  alias Oli.Publishing
  alias OliWeb.Common.{Breadcrumb, Filter, FilterBox, Listing, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, RadioButton}

  import Oli.Utils

  data breadcrumbs, :any,
    default: [Breadcrumb.new(%{full_title: "Select Source for New Section"})]

  data title, :string, default: "Select Source for New Section"
  data sources, :list, default: []
  data table_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data query, :string, default: ""
  data applied_query, :string, default: ""
  data view_type, :atom, default: :card

  @table_filter_fn &OliWeb.Delivery.SelectSource.filter_rows/3
  @table_push_patch_path &OliWeb.Delivery.SelectSource.live_path/2

  def breadcrumbs(:admin) do
    OliWeb.OpenAndFreeController.set_breadcrumbs() |> breadcrumb(:admin)
  end

  def breadcrumbs(:lms_instructor) do
    breadcrumb(
      [
        Breadcrumb.new(%{
          full_title: "Create Course Section",
          link: Routes.delivery_path(OliWeb.Endpoint, :index)
        })
      ],
      :lms_instructor,
      "Start"
    )
  end

  def breadcrumbs(:independent_learner) do
    breadcrumb(
      [
        Breadcrumb.new(%{
          full_title: "My Courses",
          link: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)
        })
      ],
      :independent_learner
    )
  end

  defp breadcrumb(previous, type, title \\ "Select Source") do
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
    context = SessionContext.init(session)

    # SelectSource used in three routes.
    # live_action is :independent_learner, :admin or :lms_instructor
    live_action = socket.assigns.live_action

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
      retrieve_all_sources(live_action, %{user: user, lti_params: lti_params})
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

    {:ok, table_model} = OliWeb.Delivery.SelectSource.TableModel.new(sources, context)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs(live_action),
       total_count: length(sources),
       table_model: table_model,
       sources: sources,
       user: user,
       lti_params: lti_params,
       live_action: live_action
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="d-flex flex-column mt-4 mx-4">
        <FilterBox table_model={@table_model} show_sort={is_cards_view?(@live_action, @view_type)} show_more_opts={is_instructor?(@live_action)}>
          <Filter query={@applied_query} apply={"apply_search"} change={"change_search"} reset="reset_search"/>

          <:extra_opts>
            <div class="flex flex-row justify-end py-3">
              <Form for={:view} change="update_view_type">
                <Field name={:type} class="control w-100 d-flex align-items-center">
                  <div class="btn-group btn-group-toggle">
                    <label class={"btn btn-outline-secondary" <> if @view_type == :card, do: " active", else: ""}>
                      <RadioButton value="card" checked={@view_type == :card} opts={hidden: true}/>
                      <i class='fa fa-th'></i>
                    </label>
                    <label class={"btn btn-outline-secondary" <> if @view_type == :list, do: " active", else: ""}>
                      <RadioButton value="list" checked={@view_type == :list} opts={hidden: true}/>
                      <i class='fa fa-list'></i>
                    </label>
                  </div>
                </Field>
              </Form>
            </div>
          </:extra_opts>
        </FilterBox>

        <Listing
          filter={@applied_query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          selected="selected"
          sort="sort"
          page_change="page_change"
          show_bottom_paging={false}
          cards_view={is_cards_view?(@live_action, @view_type)}
        />

        {#if is_lms_instructor?(@live_action) and is_nil(@user.author)}
          <div class="card max-w-lg mx-auto">
            <div class="card-body text-center">
              <h5 class="card-title">Have a Course Authoring Account?</h5>
              <p class="card-text">Link your authoring account to access projects where you are a collaborator.</p>
              <a href={Routes.delivery_path(OliWeb.Endpoint, :link_account)} target="_blank" class="btn btn-primary link-account">Link Authoring Account</a>
            </div>
          </div>
        {/if}
      </div>
    """
  end

  def handle_event("update_view_type", %{"view" => %{"type" => view_type}}, socket),
    do: {:noreply, assign(socket, :view_type, String.to_atom(view_type))}

  def handle_event("selected", %{"id" => source}, socket),
    do: handle_select(socket.assigns.live_action, source, socket)

  defp handle_select(:lms_instructor, source, socket) do
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

  defp retrieve_all_sources(:lms_instructor, %{user: user, lti_params: lti_params}),
    do: Delivery.retrieve_visible_sources(user, lti_params)

  defp is_instructor?(:admin), do: false
  defp is_instructor?(_), do: true

  defp is_cards_view?(:independent_learner, :card), do: true
  defp is_cards_view?(:lms_instructor, :card), do: true
  defp is_cards_view?(_, _), do: false

  defp is_lms_instructor?(:lms_instructor), do: true
  defp is_lms_instructor?(_), do: false
end
