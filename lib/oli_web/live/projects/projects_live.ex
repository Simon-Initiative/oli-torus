defmodule OliWeb.Projects.ProjectsLive do
  @moduledoc """
  LiveView implementation of projects view.
  """

  use OliWeb, :surface_view

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.TextSearch
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts
  alias OliWeb.Common.SessionContext
  alias OliWeb.Projects.TableModel
  alias Surface.Components.Form
  alias Surface.Components.Form.{TextInput, Label, ErrorTag}

  @limit 25

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Projects"})]
  data title, :string, default: "Projects"
  data payments, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data show_all, :boolean, default: true
  data show_deleted, :boolean, default: false
  data text_search, :string, default: ""

  data author, :any
  data is_admin, :boolean, default: false

  data changeset, :any, default: Project.new_project_changeset(%Project{title: ""})

  def mount(_, session, socket) do
    %SessionContext{author: author} = context = SessionContext.init(session)
    is_admin = Accounts.is_admin?(author)

    show_all =
      if is_admin do
        Accounts.get_author_preference(author, :admin_show_all_projects, true)
      else
        true
      end

    show_deleted = Accounts.get_author_preference(author, :admin_show_deleted_projects, false)

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        include_deleted: show_deleted,
        admin_show_all: show_all
      )

    {:ok, table_model} = TableModel.new(context, projects)

    total_count = determine_total(projects)

    {:ok,
     assign(
       socket,
       context: context,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       is_admin: is_admin,
       show_all: show_all,
       show_deleted: show_deleted
     )}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    %{is_admin: is_admin, show_all: show_all, show_deleted: show_deleted, author: author} =
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
        new_value when new_value != show_all and is_admin ->
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

  def render(assigns) do
    ~F"""
    <div class="projects-title-row mb-4">
      <div class="container">
        <div class="row">
          <div class="col-12">
            <div class="d-flex justify-content-between align-items-baseline">
              <div>
                {#if @is_admin}
                  <div class="form-check" style="display: inline;">
                    <input type="checkbox" class="form-check-input" id="allCheck" checked={@show_all} phx-click="toggle_show_all">
                    <label class="form-check-label" for="allCheck">Show all projects</label>
                  </div>
                {/if}
                <div class={"form-check #{if @is_admin, do: "ml-4", else: ""}"} style="display: inline;">
                  <input type="checkbox" class="form-check-input" id="deletedCheck" checked={@show_deleted} phx-click="toggle_show_deleted">
                  <label class="form-check-label" for="deletedCheck">Show deleted projects</label>
                </div>
              </div>

              <div class="flex-grow-1"></div>

              <button id="button-new-project"
                class="btn btn-sm btn-primary ml-2"
                data-toggle="modal"
                data-target="#modal-new-project">
                <i class="fa fa-plus"></i> New Project
              </button>
            </div>
          </div>

        </div>
      </div>
    </div>

    <div class="container mb-4">
      <div class="row">
        <div class="col-12">
          <TextSearch event_target={:live_view} id="text-search" apply="text_search_apply" reset="text_search_reset" change="text_search_change" text={@text_search} />
        </div>
      </div>
    </div>

    <div class="container">
      <div class="row">
        <div id="projects-table" class="col-12">
          <PagedTable page_change="paged_table_page_change" sort="paged_table_sort"
            total_count={@total_count} filter={@text_search}
            selection_change={nil} allow_selection={false}
            limit={@limit} offset={@offset} table_model={@table_model} show_bottom_paging={true} />
        </div>
      </div>
    </div>

    <div class="modal fade" id="modal-new-project" tabindex="-1" role="dialog" aria-labelledby="new-project-modal" aria-hidden="true">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">Create Project</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <Form for={@changeset} action={Routes.project_path(@socket, :create)}>
            <div class="modal-body">
              <div class="form-label-group">
                <TextInput id="input-title" field={:title} class="form-control input-bold" opts={[required: true, placeholder: "e.g. Introduction to Psychology"]}/>
                <Label field={:title} class="control-label text-secondary">This can be changed later</Label>
                <ErrorTag field={:title}></ErrorTag>
              </div>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-outline-primary" data-dismiss="modal">Cancel</button>
              <button type="submit" class="btn btn-primary" phx-disable-with="Creating Project...">Create Project</button>
            </div>
          </Form>
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

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
