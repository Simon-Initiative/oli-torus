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
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts
  alias OliWeb.Projects.TableModel
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers

  @limit 25

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Projects"})]
  data title, :string, default: "Projects"
  data payments, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data sort_by, :any, default: :title
  data sort_order, :any, default: :asc
  data filter, :string, default: ""
  data applied_filter, :string, default: ""
  data show_deleted, :boolean, default: false
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
       offset: 0,
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

    offset = OliWeb.Common.SortableTable.TableHandlers.get_int_param(params, "offset", 0)

    show_deleted =
      OliWeb.Common.SortableTable.TableHandlers.get_boolean_param(params, "show_deleted", false)

    projects =
      Course.browse_projects(
        socket.assigns.author,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        show_deleted
      )

    table_model = Map.put(table_model, :rows, projects)

    total_count = determine_total(projects)

    {:noreply,
     assign(socket,
       offset: offset,
       sort_by: table_model.sort_by_spec.name,
       sort_order: table_model.sort_order,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       show_deleted: show_deleted
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

    <div class="container">
      <div class="row">
        <div class="col-12">
          <%= live_component PagedTable, page_change: "page_change", sort: "sort",
          total_count: @total_count, filter: "",
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

  def handle_event("toggle_show_deleted", _, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{
           sort_by: socket.assigns.sort_by,
           sort_order: socket.assigns.sort_order,
           offset: socket.assigns.offset,
           show_deleted: !socket.assigns.show_deleted
         })
     )}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{
           sort_by: socket.assigns.sort_by,
           sort_order: socket.assigns.sort_order,
           offset: offset,
           show_deleted: socket.assigns.show_deleted
         })
     )}
  end

  # handle change of selection
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_order =
      case Atom.to_string(socket.assigns.sort_by) do
        ^sort_by ->
          if socket.assigns.sort_order == :asc do
            :desc
          else
            :asc
          end

        _ ->
          socket.assigns.sort_order
      end

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(socket, OliWeb.Projects.ProjectsLive, %{
           sort_by: sort_by,
           sort_order: sort_order,
           offset: socket.assigns.offset,
           show_deleted: socket.assigns.show_deleted
         })
     )}
  end
end
