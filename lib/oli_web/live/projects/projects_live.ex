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
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{PagingParams, Params, SearchInput, StripedPagedTable}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Icons
  alias OliWeb.Projects.{CreateProjectModal, TableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @limit 20

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

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        include_deleted: show_deleted,
        admin_show_all: show_all
      )

    {:ok, table_model} = TableModel.new(ctx, projects)

    total_count = determine_total(projects)

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
       limit: @limit
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
    } =
      socket.assigns

    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    text_search = get_param(params, "text_search", "")
    limit = get_int_param(params, "limit", @limit)

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
        text_search: text_search
      )

    table_model = Map.put(table_model, :rows, projects)

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
       limit: limit
     )}
  end

  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>

    <div>
      <div class="flex justify-between items-center px-4">
        <span class="text-[#353740] dark:text-[#EEEBF5] text-2xl font-bold leading-loose">
          Browse Projects
        </span>
        <button
          id="button-new-project"
          class="btn btn-sm rounded-md bg-[#0080FF] text-[#FFFFFF] font-semibold shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-4 py-2"
          phx-click="show_create_project_modal"
        >
          <i class="fa fa-plus pr-2"></i> New Project
        </button>
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

      <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
        <.form for={%{}} phx-change="text_search_change" class="w-56">
          <SearchInput.render id="text-search" name="project_name" text={@text_search} />
        </.form>

        <button class="ml-2 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1 opacity-50 hover:cursor-not-allowed">
          <Icons.filter class="stroke-[#353740] dark:stroke-[#EEEBF5]" /> Filter
        </button>

        <button
          class="ml-2 mr-4 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1 hover:text-[#006CD9] dark:hover:text-[#4CA6FF]"
          phx-click="clear_all_filters"
        >
          <Icons.trash /> Clear All Filters
        </button>
      </div>

      <div class="grid grid-cols-12">
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
    patch_with(socket, %{text_search: project_name})
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

  def handle_event("clear_all_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/authoring/projects")}
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

  defp current_params(socket) do
    %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: socket.assigns.offset,
      limit: socket.assigns.limit,
      show_deleted: socket.assigns.show_deleted,
      text_search: socket.assigns.text_search,
      show_all: socket.assigns.show_all
    }
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc
end
