defmodule OliWeb.Resources.PagesView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  import Oli.Authoring.Editing.Utils

  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb, FilterBox}
  alias Oli.Resources.PageBrowse
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Resources.PageBrowseOptions
  alias OliWeb.Common.SessionContext
  alias OliWeb.Resources.PagesTableModel
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Authoring.Editing.ContainerEditor
  alias OliWeb.Common.Hierarchy
  alias OliWeb.Common.Hierarchy.MoveModal
  alias Oli.Resources.{Revision}
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Authoring.Course.Project

  data title, :string, default: "All Pages"
  data project, :any
  data breadcrumbs, :list
  data author, :any
  data pages, :list

  @limit 25

  defp limit, do: @limit
  defp graded_opts, do: [{true, "Graded"}, {false, "Practice"}]
  defp type_opts, do: [{true, "Regular"}, {false, "Adaptive"}]

  @default_options %PageBrowseOptions{
    basic: nil,
    graded: nil,
    deleted: false,
    text_search: nil
  }

  def breadcrumb(project) do
    [
      Breadcrumb.new(%{
        full_title: "Project Overview",
        link: Routes.project_path(OliWeb.Endpoint, :overview, project.slug)
      }),
      Breadcrumb.new(%{full_title: "All Pages"})
    ]
  end

  def mount(
        %{"project_id" => project_slug},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    socket =
      with {:ok, author} <- Accounts.get_author(author_id) |> trap_nil(),
           {:ok, project} <- Oli.Authoring.Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project) do
        context = SessionContext.init(session)

        pages =
          PageBrowse.browse_pages(
            project,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :asc, field: :title},
            @default_options
          )

        total_count = determine_total(pages)
        {:ok, table_model} = PagesTableModel.new(pages, project, context)

        assign(socket,
          modal: nil,
          context: context,
          breadcrumbs: breadcrumb(project),
          project: project,
          author: author,
          total_count: total_count,
          table_model: table_model,
          options: @default_options
        )
      else
        _ ->
          socket
          |> put_flash(:info, "You do not have permission to access this course project")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))
      end

    {:ok, socket}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %PageBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      deleted: false,
      graded: get_boolean_param(params, "graded", nil),
      basic: get_boolean_param(params, "basic", nil)
    }

    pages =
      PageBrowse.browse_pages(
        socket.assigns.project,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, pages)
    total_count = determine_total(pages)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}
    <div>

      <FilterBox
        card_header_text="Browse All Pages"
        card_body_text=""
        table_model={@table_model}
        show_sort={false}
        show_more_opts={true}>
        <TextSearch id="text-search" text={@options.text_search}/>

        <:extra_opts>

          <form :on-change="change_graded" class="d-flex">
            <select name="graded" id="select_graded" class="custom-select custom-select mr-2">
              <option value="" selected>Grading Type</option>
              {#for {value, str} <- graded_opts()}
                <option value={Kernel.to_string(value)} selected={@options.graded == value}>{str}</option>
              {/for}
            </select>
          </form>

          <form :on-change="change_type" class="d-flex">
            <select name="type" id="select_type" class="custom-select custom-select mr-2">
              <option value="" selected>Page Type</option>
              {#for {value, str} <- type_opts()}
                <option value={Kernel.to_string(value)} selected={@options.basic == value}>{str}</option>
              {/for}
            </select>
          </form>
        </:extra_opts>
      </FilterBox>

      <div class="my-3 d-flex flex-row">
        <div class="flex-grow-1" />
        <button class="btn btn-primary" :on-click="create_page">Create Page</button>
      </div>

      <PagedTable
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={limit()}/>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.project.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search,
               basic: socket.assigns.options.basic,
               graded: socket.assigns.options.graded
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("change_graded", %{"graded" => graded}, socket) do
    patch_with(socket, %{graded: graded})
  end

  def handle_event("change_type", %{"type" => basic}, socket) do
    patch_with(socket, %{basic: basic})
  end

  def handle_event("show_delete_modal", %{"slug" => slug}, socket) do
    %{project: project, author: author} = socket.assigns

    revision = Enum.find(socket.assigns.table_model.rows, fn r -> r.slug == slug end)

    container =
      case PageBrowse.find_parent_container(project, revision) do
        [] -> nil
        [container] -> container
      end

    assigns = %{
      id: "delete_#{revision.slug}",
      redirect_url:
        Routes.live_path(
          socket,
          __MODULE__,
          socket.assigns.project.slug,
          %{
            sort_by: socket.assigns.table_model.sort_by_spec.name,
            sort_order: socket.assigns.table_model.sort_order,
            offset: socket.assigns.offset,
            text_search: socket.assigns.options.text_search
          }
        ),
      revision: revision,
      container: container,
      project: project,
      author: author
    }

    {:noreply,
     assign(socket,
       modal: %{component: OliWeb.Curriculum.DeleteModal, assigns: assigns}
     )}
  end

  def handle_event("show_options_modal", %{"slug" => slug}, socket) do
    %{project: project} = socket.assigns

    assigns = %{
      id: "options_#{slug}",
      redirect_url:
        Routes.live_path(
          socket,
          __MODULE__,
          socket.assigns.project.slug,
          %{
            sort_by: socket.assigns.table_model.sort_by_spec.name,
            sort_order: socket.assigns.table_model.sort_order,
            offset: socket.assigns.offset,
            text_search: socket.assigns.options.text_search
          }
        ),
      revision: Enum.find(socket.assigns.table_model.rows, fn r -> r.slug == slug end),
      project: project
    }

    {:noreply,
     assign(socket,
       modal: %{component: OliWeb.Curriculum.OptionsModal, assigns: assigns}
     )}
  end

  def handle_event("show_move_modal", %{"slug" => slug}, socket) do
    %{project: project, table_model: table_model} = socket.assigns

    revision = Enum.find(table_model.rows, fn r -> r.slug == slug end)
    hierarchy = AuthoringResolver.full_hierarchy(project.slug)

    node =
      case Hierarchy.find_in_hierarchy(hierarchy, fn n -> n.revision.slug == slug end) do
        nil -> disconnected_page_node(revision, project)
        found -> found
      end

    from_container =
      Hierarchy.find_parent_in_hierarchy(hierarchy, fn n ->
        n.revision.slug == slug
      end)

    active =
      case from_container do
        nil -> hierarchy
        other -> other
      end

    assigns = %{
      id: "move_#{slug}",
      node: node,
      hierarchy: hierarchy,
      from_container: from_container,
      active: active
    }

    {:noreply,
     assign(socket,
       modal: %{component: MoveModal, assigns: assigns}
     )}
  end

  def handle_event(
        "MoveModal.move_item",
        %{"from_uuid" => from_uuid, "to_uuid" => to_uuid},
        socket
      ) do
    %{
      author: author,
      project: project,
      modal: %{assigns: %{node: node, hierarchy: hierarchy}}
    } = socket.assigns

    %{revision: revision} = node

    from_container =
      case Hierarchy.find_parent_in_hierarchy(hierarchy, from_uuid) do
        %{revision: from_container} -> from_container
        _ -> nil
      end

    %{revision: to_container} = Hierarchy.find_in_hierarchy(hierarchy, to_uuid)

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    {:noreply, hide_modal(socket)}
  end

  def handle_event("MoveModal.remove", %{"from_uuid" => from_uuid}, socket) do
    %{
      author: author,
      project: project,
      modal: %{assigns: %{node: node, hierarchy: hierarchy}}
    } = socket.assigns

    %{revision: revision} = node
    %{revision: from_container} = Hierarchy.find_in_hierarchy(hierarchy, from_uuid)
    to_container = nil

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    {:noreply, hide_modal(socket)}
  end

  def handle_event("MoveModal.cancel", _, socket) do
    {:noreply, hide_modal(socket)}
  end

  def handle_event("HierarchyPicker.update_active", %{"uuid" => uuid}, socket) do
    %{modal: %{assigns: %{hierarchy: hierarchy}} = modal} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | active: active
        }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  # handle clicking of the "Add Graded Assessment" or "Add Practice Page" buttons
  def handle_event("create_page", _, socket) do
    %{
      project: project,
      author: author
    } = socket.assigns

    attrs = %{
      tags: [],
      objectives: %{"attached" => []},
      children: [],
      content: %{
        "version" => "0.1.0",
        "model" => []
      },
      title: "New Page",
      graded: false,
      max_attempts: 0,
      recommended_attempts: 0,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    case ContainerEditor.add_new(
           nil,
           attrs,
           author,
           project
         ) do
      {:ok, %Revision{slug: slug}} ->
        # redirect to new page
        {:noreply,
         redirect(socket,
           to: Routes.resource_path(OliWeb.Endpoint, :edit, project.slug, slug)
         )}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create new page")}
    end
  end

  def handle_event("duplicate_page", %{"id" => page_id}, socket) do
    %{project: project, author: author} = socket.assigns
    page_id = String.to_integer(page_id)
    revision = Enum.find(socket.assigns.table_model.rows, fn r -> r.id == page_id end)

    original_page = Map.from_struct(revision)

    new_page_attrs =
      original_page
      |> Map.drop([:slug, :inserted_at, :updated_at, :resource_id, :resource])
      |> Map.put(:title, "Copy of #{original_page.title}")
      |> Map.put(:content, nil)
      |> Map.put(:author_id, author.id)

    Oli.Repo.transaction(fn ->
      with {:ok, %{revision: revision}} <-
             Oli.Authoring.Course.create_and_attach_resource(project, new_page_attrs),
           {:ok, _} <- Oli.Publishing.ChangeTracker.track_revision(project.slug, revision),
           {:ok, model_duplicated_activities} <-
             Oli.Authoring.Editing.ContainerEditor.deep_copy_activities(
               original_page.content["model"],
               project.slug,
               author
             ),
           new_content <- %{
             original_page.content
             | "model" => Enum.reverse(model_duplicated_activities)
           },
           {:ok, updated_revision} <-
             Oli.Resources.update_revision(revision, %{content: new_content}) do
        updated_revision
      else
        {:error, e} -> Oli.Repo.rollback(e)
      end
    end)

    patch_with(socket, %{})
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  defp disconnected_page_node(%Revision{} = revision, %Project{} = project) do
    %HierarchyNode{
      uuid: uuid(),
      numbering: nil,
      revision: revision,
      resource_id: revision.resource_id,
      project_id: project.id,
      children: []
    }
  end
end
