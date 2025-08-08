defmodule OliWeb.Delivery.NewCourse.SelectSource do
  use OliWeb, :live_component

  alias Oli.Delivery
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias OliWeb.Common.{Filter, FilterBox, Listing, SessionContext}
  alias OliWeb.Common.Table.SortableTableModel

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_by: :title,
    sort_order: :asc,
    query: "",
    applied_query: "",
    selection: nil
  }

  @default_view_type :card

  def update(
        %{
          session: session,
          on_select: on_select,
          current_user: current_user,
          lti_params: lti_params
        } = assigns,
        socket
      ) do
    if !socket.assigns[:loaded] do
      ctx = SessionContext.init(socket, session)
      params = socket.assigns[:params] || @default_params
      view_type = socket.assigns[:view_type] || @default_view_type

      # live_action is :independent_learner, :admin or :lms_instructor
      live_action = session["live_action"]

      sources = retrieve_all_sources(live_action, %{user: current_user, lti_params: lti_params})

      {total_count, table_model} =
        OliWeb.Delivery.NewCourse.TableModel.new(sources, ctx)
        |> elem(1)
        |> get_table_model_and_count(sources, params)

      {:ok,
       assign(socket,
         total_count: total_count,
         table_model: table_model,
         sources: sources,
         live_action: live_action,
         loaded: true,
         on_select: on_select,
         current_user: current_user,
         lti_params: lti_params,
         params: params,
         view_type: view_type
       )}
    else
      case assigns[:source] do
        nil ->
          {:ok, socket}

        source ->
          params = Map.put(socket.assigns.params, :selection, source)

          {total_count, table_model} =
            get_table_model_and_count(
              socket.assigns.table_model,
              socket.assigns.sources,
              params
            )

          {:ok,
           assign(socket, total_count: total_count, table_model: table_model, params: params)}
      end
    end
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :changeset, to_form(%{}, as: :view))

    ~H"""
    <div class="w-full">
      <FilterBox.render
        table_model={@table_model}
        sort={JS.push("sort", target: @myself)}
        show_more_opts={is_instructor?(@live_action)}
      >
        <Filter.render
          query={@params[:query]}
          apply={JS.push("apply_search", target: @myself)}
          change={JS.push("change_search", target: @myself)}
          reset={JS.push("reset_search", target: @myself)}
        />

        <:extra_opts>
          <div class="flex flex-row justify-end border-l border-l-gray-200 pl-4">
            <.form
              id="update_view_type"
              for={@changeset}
              phx-change="update_view_type"
              phx-target={@myself}
            >
              <div name={:type} class="control w-100 d-flex align-items-center">
                <div class="flex text-white dark:text-delivery-body-color-dark">
                  <label class={"#{if @view_type == :card, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white dark:bg-gray-600 text-black dark:text-white"} cursor-pointer text-center block rounded-l-sm py-1 h-8 w-10"}>
                    <.input
                      field={@changeset[:type]}
                      id="card-view-type"
                      type="radio"
                      class="hidden"
                      value="card"
                      checked={@view_type == :card}
                    />
                    <i class="fa fa-th" />
                  </label>
                  <label class={"#{if @view_type == :list, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white dark:bg-gray-600 text-black dark:text-white"} cursor-pointer text-center block rounded-r-sm py-1 h-8 w-10"}>
                    <.input
                      field={@changeset[:type]}
                      id="list-view-type"
                      type="radio"
                      class="hidden"
                      value="list"
                      checked={@view_type == :card}
                    />
                    <i class="fa fa-list" />
                  </label>
                </div>
              </div>
            </.form>
          </div>
        </:extra_opts>
      </FilterBox.render>

      <Listing.render
        filter={@params[:applied_query]}
        table_model={@table_model}
        total_count={@total_count}
        offset={@params[:offset]}
        limit={@params[:limit]}
        selected={@on_select}
        sort={JS.push("sort", target: @myself)}
        page_change={JS.push("page_change", target: @myself)}
        show_bottom_paging={false}
        cards_view={is_cards_view?(@live_action, @view_type)}
      />

      <%= if is_lms_instructor?(@live_action) and is_nil(@current_user.author) do %>
        <div class="card max-w-lg mx-auto">
          <div class="card-body text-center">
            <h5 class="card-title">Have a Course Authoring Account?</h5>
            <p class="card-text">
              Link your authoring account to access projects where you are a collaborator.
            </p>
            <a
              href={~p"/users/link_account"}
              target="_blank"
              class="btn btn-primary link-account inline-block my-2"
            >
              Link Authoring Account
            </a>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_table_model_and_count(
         table_model,
         sources,
         params,
         opts \\ [update_sort_params: false]
       ) do
    filtered_table_model = filter(table_model, sources, params)

    table_model =
      filtered_table_model
      |> sort(params, opts)
      |> paginate(params)
      |> maybe_mark_selected_source(params)

    {length(filtered_table_model.rows), table_model}
  end

  defp sort(table_model, params, opts) do
    case opts[:update_sort_params] do
      true -> SortableTableModel.update_sort_params(table_model, params.sort_by)
      false -> table_model
    end
    |> SortableTableModel.update_from_params(params)
  end

  defp filter(table_model, sources, params) do
    case params.applied_query do
      "" ->
        Map.put(table_model, :rows, sources)

      query ->
        rows =
          Enum.filter(sources, fn source ->
            title =
              case Map.get(source, :type) do
                nil -> source.project.title
                :blueprint -> source.title
              end

            String.contains?(
              String.downcase(title),
              String.downcase(query)
            )
          end)

        Map.put(table_model, :rows, rows)
    end
  end

  defp paginate(table_model, params) do
    rows = Enum.slice(table_model.rows, params.offset, params.limit)

    Map.put(table_model, :rows, rows)
  end

  defp maybe_mark_selected_source(table_model, params) do
    source_id =
      case (Regex.run(~r/[^\d]*(\d+)/, params[:selection] || "", capture: :all_but_first) || [])
           |> Enum.at(0) do
        nil -> nil
        id -> String.to_integer(id)
      end

    rows =
      Enum.map(table_model.rows, fn row ->
        if Map.get(row, :id) == source_id do
          Map.put(row, :selected, true)
        else
          Map.delete(row, :selected)
        end
      end)

    Map.put(table_model, :rows, rows)
  end

  def handle_event("update_view_type", %{"view" => %{"type" => view_type}}, socket),
    do: {:noreply, assign(socket, :view_type, String.to_atom(view_type))}

  def handle_event("change_search", %{"value" => value}, socket) do
    params = Map.put(socket.assigns.params, :query, value)

    {:noreply, assign(socket, params: params)}
  end

  def handle_event("apply_search", _, socket) do
    params = Map.put(socket.assigns.params, :applied_query, socket.assigns.params.query)

    {total_count, table_model} =
      get_table_model_and_count(
        socket.assigns.table_model,
        socket.assigns.sources,
        params
      )

    {:noreply, assign(socket, total_count: total_count, table_model: table_model, params: params)}
  end

  def handle_event("reset_search", _, socket) do
    params = Map.merge(socket.assigns.params, %{query: "", applied_query: ""})

    {total_count, table_model} =
      get_table_model_and_count(
        socket.assigns.table_model,
        socket.assigns.sources,
        params
      )

    {:noreply, assign(socket, total_count: total_count, table_model: table_model, params: params)}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    params =
      Map.merge(socket.assigns.params, %{
        sort_by: sort_by,
        sort_order: socket.assigns.table_model.sort_order
      })

    {total_count, table_model} =
      get_table_model_and_count(
        socket.assigns.table_model,
        socket.assigns.sources,
        params,
        update_sort_params: true
      )

    {:noreply, assign(socket, table_model: table_model, total_count: total_count, params: params)}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    params =
      Map.put(
        socket.assigns.params,
        :offset,
        String.to_integer(offset)
      )

    {total_count, table_model} =
      get_table_model_and_count(
        socket.assigns.table_model,
        socket.assigns.sources,
        params
      )

    {:noreply, assign(socket, total_count: total_count, table_model: table_model, params: params)}
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
