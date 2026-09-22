defmodule OliWeb.Delivery.NewCourse.SelectSource do
  use OliWeb, :live_component

  alias Oli.Delivery.SectionCreation
  alias Oli.Delivery.Sections.SectionSpecification
  alias OliWeb.Common.{Filter, Listing}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.NewCourse.TableModel
  alias OliWeb.Icons

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_by: :inserted_at,
    sort_order: :desc,
    query: "",
    applied_query: "",
    selection: nil,
    source_filter: :all
  }

  @source_results_id "select_source_results"

  def update(
        %{
          ctx: ctx,
          on_select: on_select,
          actor: actor,
          current_user: current_user,
          is_admin: is_admin,
          section_spec: section_spec,
          request_path: request_path,
          base_path: base_path,
          initial_source_filter: initial_source_filter,
          initial_query: initial_query,
          initial_sort_by: initial_sort_by,
          initial_sort_order: initial_sort_order,
          initial_view_type: initial_view_type
        } = assigns,
        socket
      ) do
    if !socket.assigns[:loaded] do
      params =
        socket.assigns[:params] ||
          Map.merge(@default_params, %{
            source_filter: initial_source_filter,
            query: initial_query,
            applied_query: initial_query,
            sort_by: initial_sort_by,
            sort_order: initial_sort_order
          })

      view_type = socket.assigns[:view_type] || initial_view_type

      {role, _institution} = unpack_role_institution(section_spec, is_admin)

      sources = retrieve_all_sources(actor, section_spec)

      {total_count, table_model} =
        TableModel.new(sources, ctx)
        |> elem(1)
        |> apply_initial_sort(initial_sort_by, initial_sort_order)
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
         base_path: base_path,
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
      <h2 class="pb-2">Select Curriculum</h2>
      <p class="mt-1 mb-4">Select a curriculum source to create your course section.</p>

      <p class="mb-2 text-sm font-semibold text-Text-text-low-alpha">Filter by:</p>
      <.source_filter_tabs source_filter={@params[:source_filter]} myself={@myself} />

      <div class="mb-4 flex flex-wrap items-center gap-4">
        <div class="w-[224px] shrink-0">
          <Filter.render
            query={@params[:query]}
            apply={JS.push("change_search", target: @myself)}
            change={JS.push("change_search", target: @myself)}
            reset={JS.push("reset_search", target: @myself)}
            apply_icon={true}
            show_reset={false}
            placeholder=""
            debounce="300"
          />
        </div>

        <.sort_by_dropdown table_model={@table_model} myself={@myself} />

        <button
          type="button"
          phx-click="sort"
          phx-value-sort_by={@table_model.sort_by_spec.name}
          phx-target={@myself}
          class="flex h-[35px] w-[35px] shrink-0 items-center justify-center rounded-[3px] text-Icon-icon-default hover:bg-Fill-fill-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
          aria-label={"Sort #{if @table_model.sort_order == :desc, do: "ascending", else: "descending"}"}
        >
          <i class={"fa fa-sort-amount-#{if @table_model.sort_order == :desc, do: "up", else: "down"}"} />
        </button>

        <div :if={is_instructor?(@role)} class="border-l border-Border-border-default pl-4">
          <.view_type_toggle view_type={@view_type} changeset={@changeset} myself={@myself} />
        </div>
      </div>

      <.new_feature_banner />

      <.result_count_announcement
        total_count={@total_count}
        source_filter={@params[:source_filter]}
      />

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
        label={source_filter_label(:all)}
        active={@source_filter == :all}
        results_id={@results_id}
        myself={@myself}
      />
      <.source_filter_tab
        filter={:templates}
        label={source_filter_label(:templates)}
        active={@source_filter == :templates}
        results_id={@results_id}
        myself={@myself}
        tooltip="View and create courses from templates made by course authors."
      />
      <.source_filter_tab
        filter={:my_sections}
        label={source_filter_label(:my_sections)}
        active={@source_filter == :my_sections}
        results_id={@results_id}
        myself={@myself}
        tooltip="View and copy your previously created course sections."
      />
    </div>
    """
  end

  attr :filter, :atom, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :results_id, :string, required: true
  attr :myself, :any, required: true
  attr :tooltip, :string, default: nil

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
      phx-hook={if @tooltip, do: "GlobalTooltip"}
      data-tooltip={@tooltip}
      data-tooltip-style={if @tooltip, do: "body"}
      data-tooltip-position={if @tooltip, do: "bottom"}
      class={[
        "flex items-center justify-center p-2.5 h-[35px] rounded-[3px] border font-semibold text-base",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
        if(@active,
          do: "bg-Background-bg-primary border-Text-text-button text-Text-text-button",
          else: "bg-Background-bg-primary border-Border-border-default text-Text-text-high"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :table_model, :map, required: true
  attr :myself, :any, required: true

  # A fully custom, LiveView-driven dropdown (no native `<select>`) — a native select here
  # proved unreliable across browsers even behind an invisible-overlay + decorative-label trick
  # (duplicate native arrows, and the visible label/actual sort state falling out of sync after
  # a click-driven selection). This gives full control over both the visuals and the event flow.
  defp sort_by_dropdown(assigns) do
    ~H"""
    <div
      id="sort_by_dropdown"
      class="relative inline-flex shrink-0 items-center"
      phx-click-away={JS.hide(to: "#sort_by_menu")}
    >
      <button
        type="button"
        phx-click={JS.toggle(to: "#sort_by_menu")}
        aria-haspopup="listbox"
        aria-label={"Sort by: #{@table_model.sort_by_spec.label}"}
        class="flex items-center gap-2 rounded-[3px] border border-Border-border-default bg-Background-bg-primary py-[8px] pl-[10px] pr-8 text-base font-semibold leading-none text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
      >
        {@table_model.sort_by_spec.label}
      </button>
      <Icons.chevron_down
        width="16"
        height="16"
        class="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 text-Text-text-high"
      />
      <div
        id="sort_by_menu"
        role="listbox"
        class="hidden absolute left-0 top-full z-10 mt-1 min-w-full overflow-hidden rounded-[3px] border border-Border-border-default bg-Background-bg-primary shadow"
      >
        <%= for column_spec <- @table_model.column_specs, column_spec.name != :action do %>
          <button
            type="button"
            role="option"
            aria-selected={to_string(@table_model.sort_by_spec == column_spec)}
            phx-click={JS.push("sort", target: @myself) |> JS.hide(to: "#sort_by_menu")}
            phx-value-sort_by={column_spec.name}
            class={[
              "block w-full whitespace-nowrap px-3 py-2 text-left text-base font-semibold leading-none text-Text-text-high hover:bg-Fill-fill-hover",
              if(@table_model.sort_by_spec == column_spec, do: "bg-Fill-fill-hover")
            ]}
          >
            {column_spec.label}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :view_type, :atom, required: true
  attr :changeset, :any, required: true
  attr :myself, :any, required: true

  defp view_type_toggle(assigns) do
    ~H"""
    <.form id="update_view_type" for={@changeset} phx-change="update_view_type" phx-target={@myself}>
      <div class="flex shrink-0">
        <label class={[
          "flex h-8 w-10 cursor-pointer items-center justify-center rounded-l-[2px] border border-Border-border-default",
          if(@view_type == :card,
            do: "bg-Fill-fill-selection-active text-Icon-icon-white",
            else: "text-Icon-icon-default"
          )
        ]}>
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
        <label class={[
          "flex h-8 w-10 cursor-pointer items-center justify-center rounded-r-[2px] border border-l-0 border-Border-border-default",
          if(@view_type == :list,
            do: "bg-Fill-fill-selection-active text-Icon-icon-white",
            else: "text-Icon-icon-default"
          )
        ]}>
          <.input
            field={@changeset[:type]}
            id="list-view-type"
            type="radio"
            class="hidden"
            value="list"
            checked={@view_type == :list}
          />
          <i class="fa fa-list" />
        </label>
      </div>
    </.form>
    """
  end

  defp new_feature_banner(assigns) do
    ~H"""
    <div id="new-course-banner" class="p-4 rounded-lg bg-Table-table-select mb-4">
      <p class="m-0 text-sm text-Text-text-high">
        Create a new course section by copying all or part of an existing section. The new section will reflect the source section as it exists at the time it is copied. Changes made to the source afterward will not appear in the new section. Only course sections you currently have permission to access are shown.
      </p>
    </div>
    """
  end

  attr :total_count, :integer, required: true
  attr :source_filter, :atom, required: true

  defp result_count_announcement(assigns) do
    ~H"""
    <p class="sr-only" role="status" aria-live="polite">
      {result_count_message(@total_count, @source_filter)}
    </p>
    """
  end

  defp result_count_message(total_count, source_filter) do
    "Showing #{total_count} #{pluralize_result(total_count)} for #{source_filter_label(source_filter)}"
  end

  defp pluralize_result(1), do: "result"
  defp pluralize_result(_), do: "results"

  defp source_filter_label(:templates), do: "Templates"
  defp source_filter_label(:my_sections), do: "My Course Sections"
  defp source_filter_label(_), do: "All Sources"

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

  # Sets (not toggles) the table model's sort column/order, used only to apply a sort_by/
  # sort_order pair carried over from the URL on first load. `SortableTableModel.update_sort_params/2`
  # can't be reused here since it treats "same column" as "flip direction," which would wrongly
  # flip the order on every load where the URL's sort_by happens to match the table's own default.
  defp apply_initial_sort(table_model, sort_by, sort_order) do
    spec = Enum.find(table_model.column_specs, table_model.sort_by_spec, &(&1.name == sort_by))

    table_model
    |> Map.put(:sort_by_spec, spec)
    |> Map.put(:sort_order, sort_order)
    |> SortableTableModel.sort()
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

  def handle_event("update_view_type", %{"view" => %{"type" => view_type}}, socket) do
    socket = assign(socket, :view_type, String.to_atom(view_type))

    {:noreply, push_patch(socket, to: patch_path(socket))}
  end

  def handle_event("filter_source", %{"filter" => filter}, socket) do
    source_filter =
      case filter do
        "templates" -> :templates
        "my_sections" -> :my_sections
        _other_filter -> :all
      end

    if source_filter == :my_sections do
      :telemetry.execute(
        [:oli, :course_builder, :my_course_sections_filter_selected],
        %{count: 1},
        %{}
      )
    end

    params =
      socket.assigns.params
      |> Map.put(:source_filter, source_filter)
      |> Map.put(:offset, 0)

    socket = update_source_list(socket, params)

    {:noreply, push_patch(socket, to: patch_path(socket))}
  end

  def handle_event("change_search", %{"value" => value}, socket) do
    params =
      socket.assigns.params
      |> Map.merge(%{query: value, applied_query: value})
      |> Map.put(:offset, 0)

    socket = update_source_list(socket, params)

    {:noreply, push_patch(socket, to: patch_path(socket))}
  end

  def handle_event("reset_search", _, socket) do
    params = Map.merge(socket.assigns.params, %{query: "", applied_query: ""})

    socket = update_source_list(socket, params)

    {:noreply, push_patch(socket, to: patch_path(socket))}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    params =
      Map.merge(socket.assigns.params, %{
        sort_by: sort_by,
        sort_order: socket.assigns.table_model.sort_order
      })

    socket = update_source_list(socket, params, update_sort_params: true)

    {:noreply, push_patch(socket, to: patch_path(socket))}
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

  # Builds the current filter/search/sort/view state as a shareable, reloadable URL, omitting
  # each query param when it's at its default value (so the common "no filters applied" case
  # keeps a clean base URL, matching the existing `filter` param's established convention).
  defp patch_path(socket) do
    params = socket.assigns.params
    table_model = socket.assigns.table_model

    # Sort state is read from `table_model` (`sort_by_spec.name`/`sort_order`), not from
    # `params.sort_by`/`params.sort_order` — the "same column toggles direction" translation
    # inside `SortableTableModel.update_sort_params/2` happens *after* `params` is built in the
    # `sort` event handler, so `params`'s own sort fields lag one step behind the table's actual
    # resulting sort state right after a direction toggle.
    query =
      %{}
      |> put_unless_default("filter", params.source_filter, :all)
      |> put_unless_default("query", params.applied_query, "")
      |> put_unless_default("sort_by", table_model.sort_by_spec.name, :inserted_at)
      |> put_unless_default("sort_order", table_model.sort_order, :desc)
      |> put_unless_default("view", socket.assigns.view_type, :card)

    case query do
      empty when empty == %{} -> socket.assigns.base_path
      query -> "#{socket.assigns.base_path}?#{URI.encode_query(query)}"
    end
  end

  defp put_unless_default(query, _key, value, default) when value == default, do: query
  defp put_unless_default(query, key, value, _default), do: Map.put(query, key, to_string(value))

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
