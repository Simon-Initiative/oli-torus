defmodule OliWeb.Delivery.NewCourse.SelectSource do
  use OliWeb, :live_component

  alias Oli.Delivery.SectionCreation
  alias Oli.Delivery.Sections.SectionSpecification
  alias OliWeb.Common.{Filter, FilterBox, Listing}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.NewCourse.TableModel

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_by: :title,
    sort_order: :asc,
    query: "",
    applied_query: "",
    selection: nil,
    source_filter: :all
  }

  @default_view_type :card
  @source_results_id "select_source_results"

  def update(
        %{
          ctx: ctx,
          on_select: on_select,
          actor: actor,
          current_user: current_user,
          is_admin: is_admin,
          section_spec: section_spec,
          request_path: request_path
        } = assigns,
        socket
      ) do
    if !socket.assigns[:loaded] do
      params = socket.assigns[:params] || @default_params
      view_type = socket.assigns[:view_type] || @default_view_type

      {role, _institution} = unpack_role_institution(section_spec, is_admin)

      sources = retrieve_all_sources(actor, section_spec)

      {total_count, table_model} =
        TableModel.new(sources, ctx)
        |> elem(1)
        |> get_table_model_and_count(sources, params)

      {:ok,
       assign(socket,
         total_count: total_count,
         table_model: table_model,
         sources: sources,
         role: role,
         loaded: true,
         on_select: on_select,
         current_user: current_user,
         request_path: request_path,
         params: params,
         view_type: view_type
       )}
    else
      case assigns[:source] do
        nil ->
          {:ok, socket}

        source ->
          params = Map.put(socket.assigns.params, :selection, source)

          {:ok, update_source_list(socket, params)}
      end
    end
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assigns
      |> assign(:changeset, to_form(%{}, as: :view))
      |> assign(:source_results_id, @source_results_id)

    ~H"""
    <div class="w-full">
      <.source_filter_tabs source_filter={@params[:source_filter]} myself={@myself} />

      <FilterBox.render
        table_model={@table_model}
        sort={JS.push("sort", target: @myself)}
        show_more_opts={is_instructor?(@role)}
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

      <div id={@source_results_id}>
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
          cards_view={is_cards_view?(@role, @view_type)}
        />
      </div>

      <%= if is_lms_instructor?(@role) and is_nil(@current_user.author) do %>
        <div class="card max-w-lg mx-auto">
          <div class="card-body text-center">
            <h5 class="card-title">Have a Course Authoring Account?</h5>
            <p class="card-text">
              Link your authoring account to access projects where you are a collaborator.
            </p>
            <a
              href={~p"/users/link_account?#{%{request_path: @request_path}}"}
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

  attr :source_filter, :atom, required: true
  attr :myself, :any, required: true

  defp source_filter_tabs(assigns) do
    assigns = assign(assigns, :results_id, @source_results_id)

    ~H"""
    <div class="flex gap-4 items-center mb-4" role="tablist" aria-label="Source filters">
      <.source_filter_tab
        filter={:all}
        label="All Sources"
        active={@source_filter == :all}
        results_id={@results_id}
        myself={@myself}
      />
      <.source_filter_tab
        filter={:templates}
        label="Templates"
        active={@source_filter == :templates}
        results_id={@results_id}
        myself={@myself}
      />
      <.source_filter_tab
        filter={:my_sections}
        label="My Course Sections"
        active={@source_filter == :my_sections}
        results_id={@results_id}
        myself={@myself}
      />
    </div>
    """
  end

  attr :filter, :atom, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :results_id, :string, required: true
  attr :myself, :any, required: true

  defp source_filter_tab(assigns) do
    ~H"""
    <button
      type="button"
      id={"source-filter-tab-#{@filter}"}
      role="tab"
      aria-selected={to_string(@active)}
      aria-controls={@results_id}
      phx-click="filter_source"
      phx-value-filter={@filter}
      phx-target={@myself}
      class={[
        "p-2.5 h-[35px] rounded-[3px] border font-semibold text-base",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
        if(@active,
          do: "bg-Fill-Accent-fill-accent-blue border-Text-text-button text-Text-text-button",
          else: "bg-Background-bg-primary border-Border-border-default text-Text-text-high"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  defp update_source_list(socket, params, opts \\ [update_sort_params: false]) do
    {total_count, table_model} =
      get_table_model_and_count(
        socket.assigns.table_model,
        socket.assigns.sources,
        params,
        opts
      )

    assign(socket, total_count: total_count, table_model: table_model, params: params)
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
    rows =
      sources
      |> filter_by_source_type(params.source_filter)
      |> filter_by_query(params.applied_query)

    Map.put(table_model, :rows, rows)
  end

  defp filter_by_source_type(sources, :templates),
    do: Enum.filter(sources, &(TableModel.tag_variant(&1) == :template))

  defp filter_by_source_type(sources, :my_sections),
    do: Enum.filter(sources, &(TableModel.tag_variant(&1) == :my_section))

  defp filter_by_source_type(sources, _other_filter), do: sources

  defp filter_by_query(sources, ""), do: sources

  defp filter_by_query(sources, query) do
    Enum.filter(sources, fn source ->
      title = TableModel.source_title(source)

      String.contains?(
        String.downcase(title),
        String.downcase(query)
      )
    end)
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

  def handle_event("filter_source", %{"filter" => filter}, socket) do
    source_filter =
      case filter do
        "templates" -> :templates
        "my_sections" -> :my_sections
        _other_filter -> :all
      end

    params =
      socket.assigns.params
      |> Map.put(:source_filter, source_filter)
      |> Map.put(:offset, 0)

    {:noreply, update_source_list(socket, params)}
  end

  def handle_event("change_search", %{"value" => value}, socket) do
    params = Map.put(socket.assigns.params, :query, value)

    {:noreply, assign(socket, params: params)}
  end

  def handle_event("apply_search", _, socket) do
    params = Map.put(socket.assigns.params, :applied_query, socket.assigns.params.query)

    {:noreply, update_source_list(socket, params)}
  end

  def handle_event("reset_search", _, socket) do
    params = Map.merge(socket.assigns.params, %{query: "", applied_query: ""})

    {:noreply, update_source_list(socket, params)}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    params =
      Map.merge(socket.assigns.params, %{
        sort_by: sort_by,
        sort_order: socket.assigns.table_model.sort_order
      })

    {:noreply, update_source_list(socket, params, update_sort_params: true)}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    params =
      Map.put(
        socket.assigns.params,
        :offset,
        String.to_integer(offset)
      )

    {:noreply, update_source_list(socket, params)}
  end

  # An actor the gate would refuse is offered nothing: the list never shows a source that
  # creation would reject.
  defp retrieve_all_sources(actor, section_spec) do
    case SectionCreation.authorize_actor(actor, section_spec) do
      {:ok, authorized_spec} ->
        institution = SectionSpecification.get_institution(authorized_spec)

        (SectionCreation.permitted_publications(actor, institution) ++
           SectionCreation.permitted_products(actor, institution) ++
           SectionCreation.permitted_sections(actor, institution))
        |> Enum.sort_by(&source_title/1, :asc)
        |> Enum.with_index(fn element, index -> Map.put(element, :unique_id, index) end)

      {:error, _reason} ->
        []
    end
  end

  defp source_title(source), do: Map.get(source, :title) || source.project.title

  defp is_instructor?(:admin), do: false
  defp is_instructor?(_), do: true

  defp is_cards_view?(:independent_learner, :card), do: true
  defp is_cards_view?(:lms_instructor, :card), do: true
  defp is_cards_view?(_, _), do: false

  defp is_lms_instructor?(:lms_instructor), do: true
  defp is_lms_instructor?(_), do: false

  defp unpack_role_institution(%SectionSpecification.Lti{institution: institution}, _is_admin),
    do: {:lms_instructor, institution}

  defp unpack_role_institution(%SectionSpecification.Direct{}, _is_admin = true),
    do: {:admin, nil}

  defp unpack_role_institution(%SectionSpecification.Direct{}, _is_admin),
    do: {:independent_learner, nil}
end
