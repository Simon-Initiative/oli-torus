defmodule OliWeb.ObjectivesLive.Objectives do
  @moduledoc """
    LiveView implementation of an objective editor.
  """
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers
  use OliWeb.Common.Modal

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.{Revision, ResourceType}
  alias OliWeb.Common.{Breadcrumb, Filter, FilterBox}
  alias OliWeb.Common.Listing, as: Table

  alias OliWeb.ObjectivesLive.{
    DeleteModal,
    FormModal,
    TableModel,
    Listing,
    SelectExistingSubModal,
    SelectionsModal
  }

  alias OliWeb.Router.Helpers, as: Routes

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.objectives, fn obj ->
      String.contains?(String.downcase(obj.title), query_str)
    end)
  end

  def live_path(socket, params),
    do: Routes.live_path(socket, __MODULE__, socket.assigns.project.slug, params)

  def mount(
        %{"project_id" => project_slug},
        _session,
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)
    author = socket.assigns.current_author

    {all_objectives, all_children, objectives, table_model} =
      build_objectives(project, [], fn socket -> socket end, true)

    {:ok,
     assign(socket,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Objectives"})],
       project: project,
       author: author,
       objectives: objectives,
       table_model: table_model,
       total_count: length(objectives),
       all_objectives: all_objectives,
       all_children: all_children,
       objective_attachments: [],
       title: "Objectives",
       query: "",
       offset: 0,
       limit: 20
     )
     |> attach_hook(:has_show_links_uri_hash, :handle_params, fn _params, uri, socket ->
       {:cont,
        assign_new(socket, :has_show_links_uri_hash, fn ->
          String.contains?(uri, "#show_links")
        end)}
     end)}
  end

  defp build_objectives(project, objectives_attachments, flash_fn, first_load \\ false) do
    all_objectives =
      project
      |> ObjectiveEditor.fetch_objective_mappings()
      |> Enum.map(& &1.revision)

    all_children =
      all_objectives
      |> Enum.reduce([], fn rev, acc -> rev.children ++ acc end)
      |> Enum.uniq()

    objectives =
      Enum.reduce(all_objectives, [], fn rev, acc ->
        case Enum.find(all_children, fn child_id -> child_id == rev.resource_id end) do
          nil ->
            mapped_children =
              Enum.map(rev.children, fn resource_id ->
                Enum.find(all_objectives, fn rev -> rev.resource_id == resource_id end)
              end)

            [
              Map.merge(
                rev,
                %{
                  children: mapped_children,
                  sub_objectives_count: length(mapped_children),
                  page_attachments_count: 0,
                  page_attachments: [],
                  activity_attachments_count: 0
                }
              )
            ] ++ acc

          _ ->
            acc
        end
      end)

    {:ok, table_model} = TableModel.new(objectives)

    pid = self()

    if first_load do
      Task.async(fn ->
        publication = Publishing.project_working_publication(project.slug)
        objectives_attachments = Publishing.find_attached_objectives(publication.id)

        send(pid, {:finish_attachments, {objectives_attachments, flash_fn}})
      end)
    else
      send(pid, {:finish_attachments, {objectives_attachments, flash_fn}})
    end

    {all_objectives, all_children, objectives, table_model}
  end

  defp return_updated_data(project, flash_fn, socket) do
    {all_objectives, all_children, objectives, table_model} =
      build_objectives(project, socket.assigns.objectives_attachments, flash_fn)

    {:noreply,
     socket
     |> assign(
       objectives: objectives,
       table_model: table_model,
       total_count: length(objectives),
       all_objectives: all_objectives,
       all_children: all_children
     )
     |> hide_modal(modal_assigns: nil)
     |> push_patch(to: live_path(socket, socket.assigns.params))}
  end

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <div class="container mx-auto">
      <FilterBox.render
        table_model={@table_model}
        show_more_opts={false}
        card_header_text="Learning Objectives"
        card_body_text={card_body_text(assigns)}
      >
        <Filter.render
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}
        />
      </FilterBox.render>

      <div class="d-flex flex-row-reverse">
        <button class="btn btn-primary" phx-click="display_new_modal">Create new Objective</button>
      </div>

      <div id="objectives-table" class="my-4">
        <Table.render
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort="sort"
          page_change="page_change"
          show_bottom_paging={false}
          additional_table_class="table-sm text-center"
          with_body={true}
        >
          <Listing.render
            revision_history_link={
              (assigns[:has_show_links_uri_hash] || false) and
                Accounts.at_least_content_admin?(@author)
            }
            rows={@table_model.rows}
            selected={@selected}
            project_slug={@project.slug}
          />
        </Table.render>
      </div>
    </div>
    """
  end

  defp card_body_text(assigns) do
    ~H"""
    Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies.
    <br /> Refer to the
    <a
      class="external"
      href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html"
      target="_blank"
    >
      CMU Eberly Center guide on learning objectives
    </a> to learn more about the importance of attaching learning objectives to pages and activities.
    """
  end

  defp new_modal(form, socket) do
    modal_assigns = %{
      id: "new_objective_modal",
      form: form,
      action: :new,
      on_click: "new"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("hide_modal", _, socket),
    do: {:noreply, hide_modal(socket, modal_assigns: nil)}

  def handle_event("display_new_modal", _, socket),
    do: new_modal(Resources.change_revision(%Revision{}) |> to_form(), socket)

  def handle_event("display_new_sub_modal", %{"slug" => slug}, socket),
    do: new_modal(Resources.change_revision(%Revision{parent_slug: slug}) |> to_form(), socket)

  def handle_event("set_selected", %{"slug" => slug}, socket) do
    {:noreply,
     push_patch(socket,
       to: live_path(socket, Map.merge(socket.assigns.params, %{"selected" => slug}))
     )}
  end

  def handle_event(
        "new",
        %{"revision" => %{"title" => title, "parent_slug" => parent_slug}},
        socket
      ) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    flash_fn =
      case ObjectiveEditor.add_new(
             %{title: title},
             socket.assigns.author,
             project,
             parent_slug
           ) do
        {:ok, _} ->
          fn socket -> put_flash(socket, :info, "Objective successfully created") end

        {:error, _error} ->
          fn socket -> put_flash(socket, :error, "Could not create objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event("display_edit_modal", %{"slug" => slug}, socket) do
    changeset =
      socket.assigns.project.slug
      |> AuthoringResolver.from_revision_slug(slug)
      |> Resources.change_revision()

    modal_assigns = %{
      id: "edit_objective_modal",
      form: to_form(changeset),
      action: :edit,
      on_click: "edit"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("edit", %{"revision" => %{"title" => title, "slug" => slug}}, socket) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    flash_fn =
      case ObjectiveEditor.edit(
             slug,
             %{title: title},
             socket.assigns.author,
             project
           ) do
        {:ok, _} ->
          fn socket -> put_flash(socket, :info, "Objective successfully updated") end

        {:error, %Ecto.Changeset{} = _changeset} ->
          fn socket -> put_flash(socket, :error, "Could not update objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event("display_add_existing_sub_modal", %{"slug" => slug}, socket) do
    %{project: project, all_children: all_children, all_objectives: all_objectives} =
      socket.assigns

    %{children: objective_children} = AuthoringResolver.from_revision_slug(project.slug, slug)

    sub_objectives =
      Enum.map(all_children -- objective_children, fn resource_id ->
        Enum.find(all_objectives, fn obj -> obj.resource_id == resource_id end)
      end)

    modal_assigns = %{
      id: "select_existing_sub_modal",
      parent_slug: slug,
      sub_objectives: sub_objectives,
      add: "add_existing_sub"
    }

    modal = fn assigns ->
      ~H"""
      <.live_component id="select_existing_sub_modal" module={SelectExistingSubModal} {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("display_delete_modal", %{"slug" => slug}, socket) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    %{children: children, resource_id: resource_id} =
      AuthoringResolver.from_revision_slug(project.slug, slug)

    if length(children) > 0 do
      {:noreply,
       put_flash(socket, :error, "Could not remove objective if it has sub-objectives associated")}
    else
      publication_id = Oli.Publishing.get_unpublished_publication_id!(project.id)

      case Oli.Publishing.find_objective_in_selections(resource_id, publication_id) do
        [] ->
          modal_assigns = %{
            id: "delete_objective_modal",
            slug: slug,
            project: project,
            attachment_summary:
              ObjectiveEditor.preview_objective_detatchment(resource_id, project)
          }

          modal = fn assigns ->
            ~H"""
            <DeleteModal.render {@modal_assigns} />
            """
          end

          {:noreply,
           show_modal(
             socket,
             modal,
             modal_assigns: modal_assigns
           )}

        selections ->
          modal_assigns = %{
            id: "selections_modal",
            selections: selections,
            project_slug: project.slug
          }

          modal = fn assigns ->
            ~H"""
            <SelectionsModal.render {@modal_assigns} />
            """
          end

          {:noreply,
           assign(
             socket,
             modal,
             modal_assigns: modal_assigns
           )}
      end
    end
  end

  def handle_event("delete", %{"slug" => slug} = params, socket) do
    socket = clear_flash(socket)

    parent_slug = Map.get(params, "parent_slug", "")
    %{project: project, author: author, objectives: objectives} = socket.assigns
    %{resource_id: resource_id} = AuthoringResolver.from_revision_slug(project.slug, slug)

    ObjectiveEditor.detach_objective(resource_id, project, author)

    {parents, parent_to_detach_slug} =
      Enum.reduce(objectives, {[], ""}, fn objective, {parents, parent_to_detach_slug} ->
        case Enum.find(objective.children, fn child -> !is_nil(child) && child.slug == slug end) do
          nil ->
            {parents, parent_to_detach_slug}

          _ ->
            if objective.slug == parent_slug,
              do: {[objective | parents], objective.slug},
              else: {[objective | parents], parent_to_detach_slug}
        end
      end)

    delete_fn =
      if length(parents) <= 1 do
        fn ->
          ObjectiveEditor.delete(
            slug,
            author,
            project,
            AuthoringResolver.from_revision_slug(project.slug, parent_to_detach_slug)
          )
        end
      else
        fn ->
          ObjectiveEditor.remove_sub_objective_from_parent(
            slug,
            author,
            project,
            AuthoringResolver.from_revision_slug(project.slug, parent_to_detach_slug)
          )
        end
      end

    flash_fn =
      case delete_fn.() do
        {:ok, _} ->
          fn socket -> put_flash(socket, :info, "Objective successfully removed") end

        {:error, _error} ->
          fn socket -> put_flash(socket, :error, "Could not remove objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event(
        "add_existing_sub",
        %{"slug" => slug, "parent_slug" => parent_slug} = _params,
        socket
      ) do
    socket = clear_flash(socket)

    %{project: project, author: author} = socket.assigns

    flash_fn =
      case ObjectiveEditor.add_new_parent_for_sub_objective(
             slug,
             parent_slug,
             project.slug,
             author
           ) do
        {:ok, _revision} ->
          fn socket -> put_flash(socket, :info, "Sub-objective successfully added") end

        {:error, _} ->
          fn socket -> put_flash(socket, :error, "Could not add sub-objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_info({:finish_attachments, {objectives_attachments, flash_fn}}, socket) do
    page_id = ResourceType.id_for_page()
    activity_id = ResourceType.id_for_activity()

    objectives =
      Enum.reduce(socket.assigns.objectives, [], fn rev, acc ->
        resource_id = rev.resource_id

        children =
          rev.children
          |> Enum.filter(&(!is_nil(&1)))
          |> Enum.map(& &1.resource_id)

        all_page_attachments =
          Enum.filter(objectives_attachments, fn
            %{resource_type_id: ^page_id, attached_objective: resource_id} ->
              Enum.member?(children, resource_id)

            _ ->
              false
          end) ++
            for pa = %{
                  attached_objective: ^resource_id,
                  resource_type_id: ^page_id
                } <- objectives_attachments,
                do: pa

        page_attachments = Enum.uniq_by(all_page_attachments, & &1.slug)

        activity_attachments =
          for aa = %{
                attached_objective: ^resource_id,
                resource_type_id: ^activity_id
              } <- objectives_attachments,
              do: aa

        [
          Map.merge(
            rev,
            %{
              page_attachments_count: length(page_attachments),
              page_attachments: page_attachments,
              activity_attachments_count: length(activity_attachments)
            }
          )
        ] ++ acc
      end)

    {:ok, table_model} = TableModel.new(objectives)

    {:noreply,
     socket
     |> assign(
       objectives: objectives,
       table_model: table_model,
       objectives_attachments: objectives_attachments
     )
     |> flash_fn.()
     |> push_patch(to: live_path(socket, socket.assigns.params), replace: true)}
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}
end
