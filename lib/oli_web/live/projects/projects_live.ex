defmodule OliWeb.Projects.ProjectsLive do
  @moduledoc """
  LiveView implementation of projects view.
  """

  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Institutions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{PagingParams, Params, SearchInput, StripedPagedTable}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Components.FilterPanel
  alias OliWeb.Icons
  alias OliWeb.Projects.{CreateProjectModal, TableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Admin.BrowseFilters

  @limit 20
  @min_search_length 3
  @visibility_options [
    {:global, "Open"},
    {:selected, "Restricted"},
    {:authors, "Author Only"}
  ]
  @status_options [
    {:active, "Active"},
    {:deleted, "Deleted"}
  ]
  @published_options [
    {true, "Yes"},
    {false, "No"}
  ]
  @date_field_options [{"inserted_at", "Created Date"}]
  @filter_fields [
    :date,
    :tags,
    :visibility,
    :published,
    :status,
    :institution
  ]

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _session, socket) do
    author = socket.assigns.current_author
    ctx = socket.assigns.ctx
    is_content_admin = Accounts.has_admin_role?(author, :content_admin)

    show_all =
      if is_content_admin,
        do: Accounts.get_author_preference(author, :admin_show_all_projects, true),
        else: true

    show_deleted = Accounts.get_author_preference(author, :admin_show_deleted_projects, false)

    initial_search = ""
    applied_search = sanitize_search_term(initial_search)

    filters = BrowseFilters.default()
    course_filters = BrowseFilters.to_course_filters(filters)
    institutions = Institutions.list_institutions()

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :inserted_at},
        include_deleted: show_deleted,
        admin_show_all: show_all,
        text_search: applied_search,
        filters: course_filters
      )

    {:ok, table_model} =
      TableModel.new(ctx, projects,
        sort_by_spec: :inserted_at,
        sort_order: :desc,
        search_term: applied_search,
        is_admin: is_content_admin,
        current_author: author
      )

    total_count = determine_total(projects)

    export_filename = "projects-" <> Date.to_iso8601(Date.utc_today()) <> ".csv"

    {:ok,
     assign(
       socket,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       is_content_admin: is_content_admin,
       show_all: show_all,
       show_deleted: show_deleted,
       title: "Projects",
       limit: @limit,
       export_filename: export_filename,
       text_search: initial_search,
       offset: 0,
       filters: filters,
       visibility_options: @visibility_options,
       status_options: @status_options,
       published_options: @published_options,
       institution_options: institutions,
       date_field_options: @date_field_options,
       filter_fields: @filter_fields
     )}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    %{
      is_content_admin: is_content_admin,
      show_all: show_all,
      show_deleted: show_deleted,
      author: author
    } = socket.assigns

    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)

    offset = get_int_param(params, "offset", 0)
    text_search = params |> get_param("text_search", "") |> String.trim()
    applied_search = sanitize_search_term(text_search)
    limit = get_int_param(params, "limit", @limit)
    filters_state = BrowseFilters.parse(params)
    course_filters = BrowseFilters.to_course_filters(filters_state)

    # if author is an admin, get the show_all value and update if its changed
    {show_all, author} =
      case get_boolean_param(params, "show_all", show_all) do
        new_value when new_value != show_all and is_content_admin ->
          {:ok, author} =
            Accounts.set_author_preference(author, :admin_show_all_projects, new_value)

          {new_value, author}

        old_value ->
          {old_value, author}
      end

    {show_deleted, author} =
      case get_boolean_param(params, "show_deleted", show_deleted) do
        new_value when new_value != show_deleted ->
          {:ok, author} =
            Accounts.set_author_preference(author, :admin_show_deleted_projects, new_value)

          {new_value, author}

        old_value ->
          {old_value, author}
      end

    projects =
      Course.browse_projects(
        socket.assigns.author,
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        include_deleted: show_deleted,
        admin_show_all: show_all,
        text_search: applied_search,
        filters: course_filters
      )

    table_model =
      table_model
      |> Map.put(:rows, projects)
      |> Map.update!(:data, &Map.put(&1, :search_term, applied_search))

    total_count = determine_total(projects)

    {:noreply,
     assign(socket,
       author: author,
       offset: offset,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       show_deleted: show_deleted,
       show_all: show_all,
       text_search: text_search,
       limit: limit,
       filters: filters_state
     )}
  end

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <div class="h-full">
      <div class="flex justify-between items-center px-4">
        <span class="text-[#353740] dark:text-[#EEEBF5] text-2xl font-bold leading-loose">
          Browse Projects
        </span>

        <div class="flex gap-3">
          <button
            id="button-new-project"
            class="btn btn-sm rounded-md bg-[#0080FF] text-[#FFFFFF] font-semibold shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-4 py-2"
            phx-click="show_create_project_modal"
          >
            <i class="fa fa-plus pr-2"></i> New Project
          </button>
        </div>
      </div>
      <div class="projects-title-row px-4 mt-2">
        <div class="flex justify-between items-baseline">
          <div>
            <%= if @is_content_admin do %>
              <div class="form-check inline-flex items-center gap-x-1.5">
                <input
                  type="checkbox"
                  class="form-check-input"
                  id="allCheck"
                  checked={@show_all}
                  phx-click="toggle_show_all"
                />
                <label class="form-check-label" for="allCheck">Show all projects</label>
              </div>
            <% end %>
            <div class={"form-check inline-flex items-center gap-x-1.5 #{if @is_content_admin, do: "ml-4", else: ""}"}>
              <input
                type="checkbox"
                class="form-check-input"
                id="deletedCheck"
                checked={@show_deleted}
                phx-click="toggle_show_deleted"
              />
              <label class="form-check-label" for="deletedCheck">Show deleted projects</label>
            </div>
          </div>

          <div class="flex-grow-1"></div>
        </div>
      </div>

      <div class="flex justify-between">
        <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
          <.form for={%{}} phx-change="text_search_change" class="w-56">
            <SearchInput.render id="text-search" name="project_name" text={@text_search} />
          </.form>

          <.live_component
            module={FilterPanel}
            id="projects-filter-panel"
            parent_pid={self()}
            filters={@filters}
            fields={@filter_fields}
            visibility_options={@visibility_options}
            status_options={@status_options}
            published_options={@published_options}
            institution_options={@institution_options}
            date_field_options={@date_field_options}
          />
        </div>
        <a
          role="button"
          class="group mr-4 inline-flex items-center gap-1 text-sm text-Text-text-button font-bold leading-none hover:text-Text-text-button-hover"
          href={~p"/authoring/projects/export?#{current_params(assigns)}"}
          download={@export_filename}
        >
          Download CSV
          <Icons.download stroke_class="group-hover:stroke-Text-text-button-hover stroke-Text-text-button" />
        </a>
      </div>

      <div class="grid grid-cols-12 overflow-x-auto">
        <div id="projects-table" class="col-span-12">
          <StripedPagedTable.render
            table_model={@table_model}
            total_count={@total_count}
            offset={@offset}
            limit={@limit}
            render_top_info={false}
            additional_table_class="instructor_dashboard_table"
            sort="paged_table_sort"
            page_change="paged_table_page_change"
            limit_change="paged_table_limit_change"
            show_limit_change={true}
          />
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:filter_panel, :apply, filters}, socket) do
    filter_params = BrowseFilters.to_query_params(filters, as: :atoms)

    # Drop all existing filter keys from current params before merging
    # This ensures cleared filters are properly removed from the URL
    base_params = Map.drop(current_params(socket), BrowseFilters.param_keys(:atoms))

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           Map.merge(base_params, Map.merge(filter_params, %{offset: 0}))
         ),
       replace: true
     )}
  end

  def handle_info({:filter_panel, :clear}, socket) do
    # Explicitly build params without any filter params to clear them from URL
    params = %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: 0,
      limit: socket.assigns.limit,
      show_deleted: socket.assigns.show_deleted,
      text_search: socket.assigns.text_search,
      show_all: socket.assigns.show_all
    }

    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, params),
       replace: true
     )}
  end

  def handle_event("toggle_show_all", _, socket) do
    patch_with(socket, %{show_all: !socket.assigns.show_all})
  end

  def handle_event("toggle_show_deleted", _, socket) do
    patch_with(socket, %{show_deleted: !socket.assigns.show_deleted})
  end

  def handle_event("show_create_project_modal", _, socket) do
    modal_assigns = %{
      id: "create_project",
      changeset: Project.new_project_changeset(%Project{title: ""})
    }

    modal = fn assigns ->
      ~H"""
      <CreateProjectModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_project", %{"project" => %{"title" => _title}}, socket) do
    {:noreply, socket}
  end

  def handle_event("text_search_change", %{"project_name" => project_name}, socket) do
    patch_with(socket, %{text_search: String.trim(project_name)})
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.table_model.sort_by_spec.name
    current_sort_order = socket.assigns.table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    patch_with(socket, %{sort_by: new_sort_by, sort_order: sort_order})
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    patch_with(socket, %{limit: limit, offset: offset})
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, Map.merge(current_params(socket), changes)),
       replace: true
     )}
  end

  defp current_params(%Phoenix.LiveView.Socket{} = socket), do: current_params(socket.assigns)

  defp current_params(assigns) do
    base = %{
      sort_by: assigns.table_model.sort_by_spec.name,
      sort_order: assigns.table_model.sort_order,
      offset: assigns.offset,
      limit: assigns.limit,
      show_deleted: assigns.show_deleted,
      text_search: assigns.text_search,
      show_all: assigns.show_all
    }

    filter_params =
      case Map.get(assigns, :filters) do
        nil -> %{}
        filters -> BrowseFilters.to_query_params(filters, as: :atoms)
      end

    Map.merge(base, filter_params)
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp sanitize_search_term(nil), do: ""

  defp sanitize_search_term(search) when is_binary(search) do
    trimmed = String.trim(search)

    cond do
      trimmed == "" -> ""
      String.length(trimmed) < @min_search_length -> ""
      true -> trimmed
    end
  end
end
