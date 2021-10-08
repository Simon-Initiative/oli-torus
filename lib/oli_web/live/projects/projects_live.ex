defmodule OliWeb.Projects.ProjectsLive do
  @moduledoc """
  LiveView implementation of projects view.
  """

  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.{Author}
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.TextSearch
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts
  alias OliWeb.Projects.TableModel
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 25

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Projects"})]
  data title, :string, default: "Projects"
  data payments, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data show_deleted, :boolean, default: false
  data text_search, :string, default: ""

  data author, :any
  data is_admin, :boolean, default: false
  data changeset, :any, default: Project.changeset(%Project{title: ""})

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    is_admin = Accounts.is_admin?(author)

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        false
      )

    {:ok, table_model} = TableModel.new(projects, is_admin)

    total_count = determine_total(projects)

    {:ok,
     assign(
       socket,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       is_admin: is_admin
     )}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      OliWeb.Common.Table.SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    show_deleted = get_boolean_param(params, "show_deleted", false)
    text_search = get_str_param(params, "text_search", "")

    projects =
      Course.browse_projects(
        socket.assigns.author,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        show_deleted,
        text_search
      )

    table_model = Map.put(table_model, :rows, projects)

    total_count = determine_total(projects)

    {:noreply,
     assign(socket,
       offset: offset,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       show_deleted: show_deleted,
       text_search: text_search
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="projects-title-row mb-4">
      <div class="container">
        <div class="row">
          <div class="col-12">
            <div class="d-flex justify-content-between align-items-baseline">
              <div>
                <%= if @is_admin do %>
                  <div class="form-check ml-4" style="display: inline;">
                    <input type="checkbox" class="form-check-input" id="exampleCheck1" <%= if @show_deleted do "checked" else "" end %> phx-click="toggle_show_deleted">
                    <label class="form-check-label" for="deletedCheck">Show deleted projects</label>
                  </div>
                <% end %>
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
          <%= live_component TextSearch, id: "text-search", apply: "text_search_apply", reset: "text_search_reset" %>
        </div>
      </div>
    </div>

    <div class="container">
      <div class="row">
        <div class="col-12">
          <%= live_component PagedTable, page_change: "paged_table_page_change", sort: "paged_table_sort",
            total_count: @total_count, filter: @text_search,
            limit: @limit, offset: @offset, table_model: @table_model %>
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
          <%= form_for @changeset, Routes.project_path(@socket, :create), [id: "form-create-project"], fn f -> %>
            <div class="modal-body">
              <div class="form-label-group">
                <%= text_input f,
                      :title,
                      class: "form-control input-bold " <> error_class(f, :title, "is-invalid"),
                      placeholder: "Introduction to Psychology",
                      id: "input-title",
                      required: true,
                      autofocus: focusHelper(f, :title, default: true) %>
                <%= label f, :title, "This can be changed later", class: "control-label text-secondary" %>
                <%= error_tag f, :title %>
              </div>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-outline-primary" data-dismiss="modal">Cancel</button>
              <%= submit "Create Project",
                  id: "button-create-project",
                  class: "btn btn-primary",
                  phx_disable_with: "Creating Project..." %>
            </div>
          <% end %>
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
         )
     )}
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
