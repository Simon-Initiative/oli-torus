defmodule OliWeb.Workspaces.CourseAuthor.PagesLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.Common.Params
  import OliWeb.Curriculum.Utils
  import OliWeb.DelegatedEvents

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources
  alias Oli.Resources.{PageBrowse, PageBrowseOptions, Revision}
  alias OliWeb.Common.Hierarchy.MoveModal
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb, FilterBox, SessionContext}
  alias OliWeb.Components.Modal
  alias OliWeb.Curriculum.Container.ContainerLiveHelpers
  alias OliWeb.Curriculum.{OptionsModalContent, HyperlinkDependencyModal}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Workspaces.CourseAuthor.Pages.TableModel, as: PagesTableModel
  alias OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLive

  @default_limit 25

  @default_options %PageBrowseOptions{
    basic: nil,
    graded: nil,
    deleted: false,
    text_search: nil
  }

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    project = socket.assigns.project
    project_slug = project.slug
    %SessionContext{author: author} = ctx = SessionContext.init(socket, session)

    pages =
      PageBrowse.browse_pages(
        project,
        %Paging{offset: 0, limit: limit()},
        %Sorting{direction: :asc, field: :title},
        @default_options
      )

    total_count = determine_total(pages)

    container_id = Oli.Resources.ResourceType.id_for_container()
    containers = AuthoringResolver.revisions_of_type(project_slug, container_id)

    child_to_parent =
      Enum.reduce(containers, %{}, fn c, m ->
        Enum.reduce(c.children, m, fn r, a -> Map.put(a, r, c) end)
      end)

    {:ok, table_model} = PagesTableModel.new(pages, project, ctx, child_to_parent)

    project_hierarchy =
      AuthoringResolver.full_hierarchy(project_slug) |> HierarchyNode.simplify()

    {:ok,
     assign(socket,
       active_view: :pages,
       active_workspace: :course_author,
       author: author,
       breadcrumbs: breadcrumb(project),
       ctx: ctx,
       offset: get_int_param(params, "offset", 0),
       options: @default_options,
       options_modal_assigns: nil,
       project: project,
       project_hierarchy: project_hierarchy,
       resource_slug: project_slug,
       resource_title: project.title,
       table_model: table_model,
       total_count: total_count
     )}
  end

  @impl Phoenix.LiveView
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
        %Paging{offset: offset, limit: limit()},
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

  @impl Phoenix.LiveView
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

    project = socket.assigns.project

    case AuthoringResolver.find_hyperlink_references(project.slug, slug) do
      [] ->
        proceed_with_deletion_warning(socket, container, project, author, revision)

      references ->
        show_hyperlink_dependency_modal(socket, container, project, references, revision)
    end
  end

  def handle_event("DeleteModal.delete", %{"slug" => slug}, socket) do
    %{
      modal_assigns: %{
        container: container,
        project: project,
        author: author,
        revision: revision,
        redirect_url: redirect_url
      }
    } = socket.assigns

    case container do
      nil ->
        result =
          Oli.Repo.transaction(fn ->
            revision =
              Oli.Publishing.AuthoringResolver.from_revision_slug(project.slug, revision.slug)

            Oli.Publishing.ChangeTracker.track_revision(project.slug, revision, %{deleted: true})
          end)

        case result do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "#{resource_type_label(revision) |> String.capitalize()} deleted"
             )
             |> push_patch(to: redirect_url)
             |> hide_modal(modal_assigns: nil)}

          _ ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Could not delete #{resource_type_label(revision)} \"#{revision.title}\""
             )
             |> hide_modal(modal_assigns: nil)}
        end

      container ->
        case ContainerEditor.remove_child(container, project, author, slug) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "#{resource_type_label(revision) |> String.capitalize()} deleted"
             )
             |> push_patch(to: redirect_url)
             |> hide_modal(modal_assigns: nil)}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Could not delete #{resource_type_label(revision)} \"#{revision.title}\""
             )
             |> hide_modal(modal_assigns: nil)}
        end
    end
  end

  def handle_event("show_options_modal", %{"slug" => slug}, socket) do
    revision = Enum.find(socket.assigns.table_model.rows, fn r -> r.slug == slug end)

    options_modal_assigns = %{
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
      revision: revision,
      changeset: Resources.change_revision(revision),
      title: "#{resource_type_label(revision) |> String.capitalize()} Options"
    }

    {:noreply,
     assign(socket, options_modal_assigns: options_modal_assigns)
     |> push_event("js-exec", %{
       to: "#options-modal-assigns-trigger",
       attr: "data-show_modal"
     })}
  end

  def handle_event("restart_options_modal", _, socket) do
    {:noreply, assign(socket, options_modal_assigns: nil)}
  end

  def handle_event("validate-options", %{"revision" => revision_params}, socket) do
    %{options_modal_assigns: %{revision: revision} = modal_assigns} = socket.assigns

    revision_params = ContainerLiveHelpers.decode_revision_params(revision_params)

    changeset =
      revision
      |> Resources.change_revision(revision_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, options_modal_assigns: %{modal_assigns | changeset: changeset})}
  end

  def handle_event("save-options", %{"revision" => revision_params}, socket) do
    %{options_modal_assigns: %{redirect_url: redirect_url, revision: revision}, project: project} =
      socket.assigns

    revision_params = ContainerLiveHelpers.decode_revision_params(revision_params)

    case ContainerEditor.edit_page(project, revision.slug, revision_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{resource_type_label(revision) |> String.capitalize()} options saved"
         )
         |> push_navigate(to: redirect_url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
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

    modal_assigns = %{
      id: "move_#{slug}",
      node: node,
      hierarchy: hierarchy,
      from_container: from_container,
      active: active
    }

    modal = fn assigns ->
      ~H"""
      <MoveModal.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event(
        "MoveModal.move_item",
        %{"to_uuid" => to_uuid} = params,
        socket
      ) do
    %{
      author: author,
      project: project,
      modal_assigns: %{node: node, hierarchy: hierarchy}
    } = socket.assigns

    %{revision: revision} = node

    from_container =
      case params["from_uuid"] do
        nil ->
          nil

        from_uuid ->
          case Hierarchy.find_parent_in_hierarchy(hierarchy, from_uuid) do
            %{revision: from_container} -> from_container
            _ -> nil
          end
      end

    %{revision: to_container} = Hierarchy.find_in_hierarchy(hierarchy, to_uuid)

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    hide_modal(socket, modal_assigns: nil)
    |> patch_with(%{})
  end

  def handle_event("MoveModal.remove", %{"from_uuid" => from_uuid}, socket) do
    %{
      author: author,
      project: project,
      modal_assigns: %{node: node, hierarchy: hierarchy}
    } = socket.assigns

    %{revision: revision} = node
    %{revision: from_container} = Hierarchy.find_in_hierarchy(hierarchy, from_uuid)
    to_container = nil

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("MoveModal.cancel", _, socket) do
    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("HierarchyPicker.update_active", %{"uuid" => uuid}, socket) do
    %{modal_assigns: %{hierarchy: hierarchy} = modal_assigns} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    modal_assigns = %{
      modal_assigns
      | active: active
    }

    {:noreply, assign(socket, modal_assigns: modal_assigns)}
  end

  def handle_event("create_page", %{"type" => type}, socket) do
    %{
      project: project,
      author: author
    } = socket.assigns

    case ContainerEditor.add_new(
           nil,
           "Basic",
           type,
           author,
           project
         ) do
      {:ok, %Revision{slug: slug}} ->
        # redirect to new page
        {:noreply,
         redirect(socket, to: Routes.live_path(OliWeb.Endpoint, EditorLive, project.slug, slug))}

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
      |> Map.put(:title, "#{original_page.title} (copy)")
      |> Map.put(:content, nil)
      |> Map.put(:author_id, author.id)
      |> then(fn map ->
        if is_nil(map.legacy) do
          map
        else
          Map.put(map, :legacy, Map.from_struct(original_page.legacy))
        end
      end)

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

  def handle_event("dismiss", _, socket) do
    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  attr(:title, :string, default: "All Pages")
  attr(:project, :any)
  attr(:breadcrumbs, :list)
  attr(:author, :any)
  attr(:pages, :list)

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>

    <Modal.modal
      id="options_modal"
      class="w-auto min-w-[50%]"
      body_class="px-6"
      on_cancel={JS.push("restart_options_modal")}
    >
      <:title>
        <%= @options_modal_assigns[:title] %>
      </:title>

      <%= if @options_modal_assigns do %>
        <.live_component
          module={OptionsModalContent}
          id="modal_content"
          ctx={@ctx}
          redirect_url={@options_modal_assigns.redirect_url}
          revision={@options_modal_assigns.revision}
          changeset={@options_modal_assigns.changeset}
          project={@project}
          project_hierarchy={@project_hierarchy}
          validate={JS.push("validate-options")}
          submit={JS.push("save-options")}
          cancel={Modal.hide_modal("options_modal") |> JS.push("restart_options_modal")}
          form={to_form(@options_modal_assigns.changeset)}
        />
      <% end %>
      <div id="options-modal-assigns-trigger" data-show_modal={Modal.show_modal("options_modal")}>
      </div>
    </Modal.modal>

    <div class="container mx-auto">
      <div class="flex flex-row justify-between">
        <FilterBox.render
          card_header_text="Browse All Pages"
          card_body_text=""
          table_model={@table_model}
          show_sort={false}
          show_more_opts={true}
        >
          <TextSearch.render
            id="text-search"
            text={@options.text_search}
            event_target="#text-search-input"
          />

          <:extra_opts>
            <form phx-change="change_graded" class="d-flex">
              <select
                name="graded"
                id="select_graded"
                class="custom-select custom-select mr-2"
                style="width: 170px;"
              >
                <option value="" selected>Scoring Type</option>
                <option
                  :for={
                    {value, str} <-
                      graded_opts()
                  }
                  value={Kernel.to_string(value)}
                  selected={@options.graded == value}
                >
                  <%= str %>
                </option>
              </select>
            </form>

            <form phx-change="change_type" class="d-flex">
              <select
                name="type"
                id="select_type"
                class="custom-select custom-select mr-2"
                style="width: 170px;"
              >
                <option value="" selected>Page Type</option>
                <option
                  :for={
                    {value, str} <-
                      type_opts()
                  }
                  value={Kernel.to_string(value)}
                  selected={@options.basic == value}
                >
                  <%= str %>
                </option>
              </select>
            </form>
          </:extra_opts>
        </FilterBox.render>
      </div>

      <div class="dropdown btn-group flex justify-end">
        <button
          type="button"
          class="btn btn-primary dropdown-toggle"
          data-bs-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          Create <i class="fa-solid fa-caret-down ml-2"></i>
        </button>
        <div class="dropdown-menu dropdown-menu-right">
          <button
            type="button"
            class="dropdown-item"
            phx-click="create_page"
            phx-value-type="Unscored"
          >
            Practice Page
          </button>
          <button type="button" class="dropdown-item" phx-click="create_page" phx-value-type="Scored">
            Scored Assessment
          </button>
          <%= if Oli.Features.enabled?("adaptivity") do %>
            <button
              type="button"
              class="dropdown-item"
              phx-click="create_page"
              phx-value-type="Adaptive"
            >
              Adaptive Page
            </button>
          <% end %>
        </div>
      </div>

      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={limit()}
        scrollable={false}
        no_records_message="There are no pages in this project"
      />
    </div>
    """
  end

  defp breadcrumb(project) do
    [
      Breadcrumb.new(%{
        full_title: "Project Overview",
        link: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug)
      }),
      Breadcrumb.new(%{full_title: "All Pages"})
    ]
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  defp patch_with(socket, changes) do
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
               graded: socket.assigns.options.graded,
               sidebar_expanded: socket.assigns.sidebar_expanded
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp show_hyperlink_dependency_modal(socket, container, project, references, revision) do
    modal_assigns = %{
      id: "not_empty_#{revision.slug}",
      revision: revision,
      container: container,
      project: project,
      hyperlinks: references
    }

    modal = fn assigns ->
      ~H"""
      <HyperlinkDependencyModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  defp proceed_with_deletion_warning(socket, container, project, author, revision) do
    modal_assigns = %{
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

    modal = fn assigns ->
      ~H"""
      <OliWeb.Curriculum.DeleteModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
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

  defp limit, do: @default_limit
  defp graded_opts, do: [{true, "Scored"}, {false, "Practice"}]
  defp type_opts, do: [{true, "Regular"}, {false, "Adaptive"}]
end
