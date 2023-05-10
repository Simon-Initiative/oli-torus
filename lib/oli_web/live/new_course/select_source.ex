defmodule OliWeb.Delivery.NewCourse.SelectSource do
  use Surface.LiveComponent

  alias Oli.Delivery
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias OliWeb.Common.{Filter, FilterBox, Listing, SessionContext}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, RadioButton}

  data sources, :list, default: []
  data table_model, :struct
  data total_count, :integer, default: 0
  data view_type, :atom, default: :card
  data live_action, :atom

  data params, :map,
    default: %{
      offset: 0,
      limit: 20,
      sort_by: "title",
      sort_order: "asc",
      query: ""
    }

  prop session, :map, required: true
  prop on_select, :event, required: true
  prop on_select_target, :any, required: true
  prop current_user, :map, required: true
  prop lti_params, :map, required: true

  def update(
        %{
          session: session,
          on_select: on_select,
          on_select_target: on_select_target,
          current_user: current_user,
          lti_params: lti_params
        } = assigns,
        socket
      ) do
    if !socket.assigns[:loaded] do
      context = SessionContext.init(session)

      # live_action is :independent_learner, :admin or :lms_instructor
      live_action = session["live_action"]

      sources = retrieve_all_sources(live_action, %{user: current_user, lti_params: lti_params})

      {:ok, table_model} = OliWeb.Delivery.NewCourse.TableModel.new(sources, context)
      table_model = mark_selected_row(table_model, assigns[:source])

      {:ok,
       assign(socket,
         total_count: length(sources),
         table_model: table_model,
         sources: sources,
         live_action: live_action,
         loaded: true,
         on_select: on_select,
         on_select_target: on_select_target,
         current_user: current_user,
         lti_params: lti_params
       )}
    else
      case assigns[:source] do
        nil ->
          {:ok, socket}

        source ->
          table_model = mark_selected_row(socket.assigns.table_model, source)

          {:ok, assign(socket, table_model: table_model)}
      end
    end
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~F"""
    <div class="w-full">
      <FilterBox
        card_header_text={nil}
        card_body_text={nil}
        table_model={@table_model}
        sort="sort"
        show_more_opts={is_instructor?(@live_action)}
      >
        <Filter
          query={@params[:query]}
          apply="apply_search"
          change="change_search"
          reset="reset_search"
        />

        <:extra_opts>
          <div class="flex flex-row justify-end border-l border-l-gray-200 pl-4">
            <Form for={:view} change="update_view_type">
              <Field name={:type} class="control w-100 d-flex align-items-center">
                <div class="flex text-white dark:text-delivery-body-color-dark">
                  <label class={"#{if @view_type == :card, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white dark:bg-gray-600 text-black dark:text-white"} cursor-pointer text-center block rounded-l-sm py-1 h-8 w-10"}>
                    <RadioButton class="hidden" value="card" checked={@view_type == :card} opts={hidden: true} />
                    <i class="fa fa-th" />
                  </label>
                  <label class={"#{if @view_type == :list, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white dark:bg-gray-600 text-black dark:text-white"} cursor-pointer text-center block rounded-r-sm py-1 h-8 w-10"}>
                    <RadioButton class="hidden" value="list" checked={@view_type == :list} opts={hidden: true} />
                    <i class="fa fa-list" />
                  </label>
                </div>
              </Field>
            </Form>
          </div>
        </:extra_opts>
      </FilterBox>

      <Listing
        filter={@params[:query]}
        table_model={@table_model}
        total_count={@total_count}
        offset={@params[:offset]}
        limit={@params[:limit]}
        selected={@on_select}
        selected_target={@on_select_target}
        sort="sort"
        page_change="page_change"
        show_bottom_paging={false}
        cards_view={is_cards_view?(@live_action, @view_type)}
      />

      {#if is_lms_instructor?(@live_action) and is_nil(@current_user.author)}
        <div class="card max-w-lg mx-auto">
          <div class="card-body text-center">
            <h5 class="card-title">Have a Course Authoring Account?</h5>
            <p class="card-text">Link your authoring account to access projects where you are a collaborator.</p>
            <a
              href={Routes.delivery_path(OliWeb.Endpoint, :link_account)}
              target="_blank"
              class="btn btn-primary link-account"
            >Link Authoring Account</a>
          </div>
        </div>
      {/if}
    </div>
    """
  end

  defp mark_selected_row(table_model, nil), do: table_model

  defp mark_selected_row(table_model, source) do
    source_id =
      case Regex.run(~r/[^\d]*(\d*)/, source, capture: :all_but_first) |> Enum.at(0) do
        nil -> nil
        id -> String.to_integer(id)
      end

    table_model_rows =
      Enum.map(table_model.rows, fn row ->
        if Map.get(row, :id) == source_id do
          Map.put(row, :selected, true)
        else
          Map.delete(row, :selected)
        end
      end)

    Map.put(table_model, :rows, table_model_rows)
  end

  defp filter_rows(sources, query) do
    case String.downcase(query) do
      "" ->
        sources

      str ->
        Enum.filter(sources, fn p ->
          title =
            case Map.get(p, :type) do
              nil -> p.project.title
              :blueprint -> p.title
            end

          String.contains?(String.downcase(title), str)
        end)
    end
  end

  def handle_event("update_view_type", %{"view" => %{"type" => view_type}}, socket),
    do: {:noreply, assign(socket, :view_type, String.to_atom(view_type))}

  def handle_event("change_search", %{"value" => value}, socket) do
    params = Map.put(socket.assigns.params, :query, value)

    {:noreply, assign(socket, params: params)}
  end

  def handle_event("apply_search", _, socket) do
    filtered_rows = filter_rows(socket.assigns.sources, socket.assigns.params.query)

    table_model = Map.put(socket.assigns.table_model, :rows, filtered_rows)

    {:noreply, assign(socket, table_model: table_model)}
  end

  def handle_event("reset_search", _, socket) do
    params = Map.put(socket.assigns.params, :query, "")
    table_model = Map.put(socket.assigns.table_model, :rows, socket.assigns.sources)

    {:noreply, assign(socket, params: params, table_model: table_model)}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    table_model =
      SortableTableModel.update_sort_params(
        socket.assigns.table_model,
        sort_by
      )

    params =
      Map.merge(socket.assigns.params, %{sort_by: sort_by, sort_order: table_model.sort_order})

    {:noreply,
     assign(socket,
       params: params,
       table_model: SortableTableModel.update_from_params(table_model, params)
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

    Enum.with_index(free_project_publications ++ products, fn element, index ->
      Map.put(element, :unique_id, index)
    end)
  end

  defp retrieve_all_sources(:independent_learner, %{user: user}),
    do:
      Publishing.retrieve_visible_sources(user, nil)
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

  defp retrieve_all_sources(:lms_instructor, %{user: user, lti_params: lti_params}),
    do:
      Delivery.retrieve_visible_sources(user, lti_params)
      |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

  defp is_instructor?(:admin), do: false
  defp is_instructor?(_), do: true

  defp is_cards_view?(:independent_learner, :card), do: true
  defp is_cards_view?(:lms_instructor, :card), do: true
  defp is_cards_view?(_, _), do: false

  defp is_lms_instructor?(:lms_instructor), do: true
  defp is_lms_instructor?(_), do: false
end
