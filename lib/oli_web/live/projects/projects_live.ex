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
  alias OliWeb.Common.{Breadcrumb, PagedTable, TextSearch}
  alias OliWeb.Projects.{CreateProjectModal, TableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @limit 25

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
       title: "Projects"
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
      OliWeb.Common.Table.SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    text_search = get_param(params, "text_search", "")

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
        %Paging{offset: offset, limit: @limit},
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
       text_search: text_search
     )}
  end

  attr(:breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Projects"})])
  attr(:title, :string, default: "Projects")
  attr(:payments, :list, default: [])

  attr(:tabel_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)
  attr(:show_all, :boolean, default: true)
  attr(:show_deleted, :boolean, default: false)
  attr(:text_search, :string, default: "")

  attr(:author, :any)
  attr(:is_content_admin, :boolean, default: false)

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <div class="container mx-auto">
      <div class="projects-title-row mb-4">
        <div class="d-flex justify-content-between align-items-baseline">
          <div>
            <%= if @is_content_admin do %>
              <div class="form-check" style="display: inline;">
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
            <div
              class={"form-check #{if @is_content_admin, do: "ml-4", else: ""}"}
              style="display: inline;"
            >
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

          <button
            id="button-new-project"
            class="btn btn-sm btn-primary ml-2"
            phx-click="show_create_project_modal"
          >
            <i class="fa fa-plus"></i> New Project
          </button>
        </div>
      </div>

      <div class="container mb-4">
        <div class="grid grid-cols-12">
          <div class="col-span-12">
            <TextSearch.render
              event_target={:live_view}
              id="text-search"
              reset="text_search_reset"
              change="text_search_change"
              text={@text_search}
            />
          </div>
        </div>
      </div>

      <div class="grid grid-cols-12">
        <div id="projects-table" class="col-span-12">
          <PagedTable.render
            page_change="paged_table_page_change"
            sort="paged_table_sort"
            total_count={@total_count}
            filter={@text_search}
            allow_selection={false}
            limit={@limit}
            offset={@offset}
            table_model={@table_model}
            show_bottom_paging={true}
          />
        </div>
      </div>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Projects.ProjectsLive,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               show_deleted: socket.assigns.show_deleted,
               text_search: socket.assigns.text_search
             },
             changes
           )
         ),
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

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
