defmodule OliWeb.Workspaces.CourseAuthor.CurriculumLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  require Logger

  import Oli.Utils, only: [value_or: 2]
  import Oli.Authoring.Editing.Utils
  import OliWeb.Curriculum.Utils
  alias Ecto.Changeset
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.GoogleDocs.{Import, Warnings}
  alias Phoenix.Component

  alias OliWeb.Curriculum.{
    Rollup,
    ActivityDelta,
    DropTarget,
    OptionsModalContent,
    DeleteModal,
    NotEmptyModal,
    HyperlinkDependencyModal
  }

  alias OliWeb.Workspaces.CourseAuthor.Curriculum.Entry
  alias OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLive

  alias OliWeb.Common.Hierarchy.MoveModal
  alias Oli.Publishing.ChangeTracker
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Accounts
  alias Oli.Repo
  alias Oli.Publishing
  alias Oli.Accounts
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Resources.Numbering
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Hierarchy
  alias Oli.Resources.Revision
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias OliWeb.Components.Modal
  alias OliWeb.Curriculum.Container.ContainerLiveHelpers

  @import_form_key :import_google_doc
  @file_id_pattern ~r/^[A-Za-z0-9_-]{10,}$/

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    project = socket.assigns.project
    project_slug = project.slug

    author = socket.assigns.current_author

    root_container = AuthoringResolver.root_container(project_slug)
    container_slug = Map.get(params, "container_slug")

    project_hierarchy = AuthoringResolver.full_hierarchy(project_slug) |> HierarchyNode.simplify()

    cond do
      # Explicitly routing to root_container, strip off the container param
      container_slug == root_container.slug && socket.assigns.live_action == :index ->
        {:ok, redirect(socket, to: Routes.live_path(socket, __MODULE__, project_slug))}

      # Routing to missing container
      container_slug && is_nil(AuthoringResolver.from_revision_slug(project_slug, container_slug)) ->
        {:ok,
         redirect(socket, to: Routes.live_path(socket, __MODULE__, project_slug, container_slug))}

      # Implicitly routing to root container or explicitly routing to sub-container
      true ->
        {:ok, container} = load_and_scrub_container(container_slug, project_slug, root_container)

        children = ContainerEditor.list_all_container_children(container, project)

        {:ok, rollup} = Rollup.new(children, project.slug)

        subscriptions = subscribe(container, children, rollup, project.slug)

        view_pref =
          case author.preferences do
            %{curriculum_view: curriculum_view} ->
              curriculum_view

            _ ->
              "Basic"
          end

        {:ok,
         assign(socket,
           resource_slug: project_slug,
           resource_title: project.title,
           children: children,
           active: :curriculum,
           breadcrumbs:
             Breadcrumb.trail_to(
               project_slug,
               container.slug,
               Oli.Publishing.AuthoringResolver,
               project.customizations,
               :workspace
             ),
           adaptivity_flag: Oli.Features.enabled?("adaptivity"),
           rollup: rollup,
           container: container,
           project: project,
           project_hierarchy: project_hierarchy,
           subscriptions: subscriptions,
           author: author,
           view: view_pref,
           selected: nil,
           resources_being_edited: get_resources_being_edited(container.children, project.id),
           numberings:
             Numbering.number_full_tree(
               Oli.Publishing.AuthoringResolver,
               project_slug,
               project.customizations
             ),
           dragging: nil,
           page_title: "Curriculum | " <> project.title,
           options_modal_assigns: nil,
           import_state: new_import_state()
         )
         |> attach_hook(:has_show_links_uri_hash, :handle_params, fn _params, uri, socket ->
           {:cont,
            assign_new(socket, :has_show_links_uri_hash, fn ->
              String.contains?(uri, "#show_links")
            end)}
         end)}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"view" => view}, _, socket) do
    %{author: author} = socket.assigns
    {:ok, _updated} = update_author_view_pref(author, view)

    {:noreply, assign(socket, view: view)}
  end

  def handle_params(params, _url, %{assigns: %{live_action: live_action}} = socket) do
    {:noreply, apply_action(socket, live_action, params)}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("show_import_modal", _, socket) do
    cond do
      not can_import?(socket.assigns.author) ->
        {:noreply, socket}

      socket.assigns.import_state.busy? ->
        {:noreply, socket}

      true ->
        socket =
          socket
          |> assign(import_state: %{new_import_state() | show?: true})
          |> push_event("js-exec", %{
            to: "#google-docs-import-modal-show",
            attr: "data-show_modal"
          })

        {:noreply, socket}
    end
  end

  def handle_event("cancel_import_modal", _, socket) do
    if socket.assigns.import_state.busy? do
      {:noreply, socket}
    else
      {:noreply, hide_import_modal(socket)}
    end
  end

  def handle_event("reset_import_modal", _, socket) do
    socket =
      socket
      |> assign(import_state: %{new_import_state() | show?: true})
      |> push_event("js-exec", %{
        to: "#google-docs-import-modal-show",
        attr: "data-show_modal"
      })

    {:noreply, socket}
  end

  def handle_event("validate_import", params, socket) do
    form_params = Map.get(params, Atom.to_string(@import_form_key), %{})

    changeset =
      form_params
      |> import_changeset()
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> put_import_state(%{changeset: changeset, error_message: nil, status: :idle})}
  end

  def handle_event("submit_import", params, socket) do
    if socket.assigns.import_state.busy? do
      {:noreply, socket}
    else
      form_params = Map.get(params, Atom.to_string(@import_form_key), %{})

      changeset =
        form_params
        |> import_changeset()
        |> Map.put(:action, :validate)

      case Changeset.apply_action(changeset, :validate) do
        {:ok, %{file_id: file_id}} ->
          {importer, opts} = resolve_importer()
          project_slug = socket.assigns.project.slug
          container_slug = socket.assigns.container.slug
          author = socket.assigns.author

          task =
            Task.Supervisor.async_nolink(Oli.TaskSupervisor, fn ->
              importer.import(project_slug, container_slug, file_id, author, opts)
            end)

          {:noreply,
           socket
           |> put_import_state(%{
             changeset: changeset,
             busy?: true,
             status: :running,
             task: task,
             task_ref: task.ref,
             warnings: [],
             error_message: nil,
             result_revision: nil,
             file_id: file_id,
             show?: true
           })
           |> push_announcement(
             gettext("Import started for FILE_ID %{file_id}.", file_id: file_id)
           )}

        {:error, invalid_changeset} ->
          {:noreply, put_import_state(socket, %{changeset: invalid_changeset, status: :idle})}
      end
    end
  end

  def handle_event("open_imported_page", _, socket) do
    case socket.assigns.import_state do
      %{result_revision: %Revision{} = revision} ->
        case revision_slug(revision) do
          nil ->
            {:noreply, hide_import_modal(socket)}

          slug ->
            {:noreply,
             socket
             |> hide_import_modal()
             |> push_navigate(
               to: Routes.live_path(socket, EditorLive, socket.assigns.project.slug, slug)
             )
             |> assign(import_state: new_import_state())}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("show_options_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project, children: children} =
      socket.assigns

    redirect_url = Routes.live_path(socket, __MODULE__, project.slug, container.slug)

    {:noreply,
     assign(socket,
       options_modal_assigns:
         ContainerLiveHelpers.build_option_modal_assigns(redirect_url, children, slug)
     )
     |> push_event("js-exec", %{
       to: "#options-modal-assigns-trigger",
       attr: "data-show_modal"
     })}
  end

  def handle_event("restart_options_modal", _, socket) do
    {:noreply, assign(socket, options_modal_assigns: nil)}
  end

  def handle_event("validate-options", %{"revision" => revision_params}, socket) do
    ContainerLiveHelpers.handle_validate_options(socket, revision_params)
  end

  def handle_event("save-options", %{"revision" => revision_params}, socket) do
    ContainerLiveHelpers.handle_save_options(socket, revision_params)
  end

  def handle_event("show_move_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project} = socket.assigns

    modal_assigns = ContainerLiveHelpers.build_modal_assigns(container.slug, project.slug, slug)

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

  def handle_event("HierarchyPicker.update_active", %{"uuid" => uuid}, socket) do
    %{modal_assigns: %{hierarchy: hierarchy} = modal_assigns} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    modal_assigns = %{
      modal_assigns
      | active: active
    }

    {:noreply, assign(socket, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "MoveModal.move_item",
        %{"uuid" => uuid, "from_uuid" => from_uuid, "to_uuid" => to_uuid},
        socket
      ) do
    %{
      author: author,
      project: project,
      modal_assigns: %{hierarchy: hierarchy}
    } = socket.assigns

    %{revision: revision} = Hierarchy.find_in_hierarchy(hierarchy, uuid)
    %{revision: from_container} = Hierarchy.find_in_hierarchy(hierarchy, from_uuid)
    %{revision: to_container} = Hierarchy.find_in_hierarchy(hierarchy, to_uuid)

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("MoveModal.remove", %{"uuid" => uuid, "from_uuid" => from_uuid}, socket) do
    %{
      author: author,
      project: project,
      modal_assigns: %{hierarchy: hierarchy}
    } = socket.assigns

    %{revision: revision} = Hierarchy.find_in_hierarchy(hierarchy, uuid)
    %{revision: from_container} = Hierarchy.find_in_hierarchy(hierarchy, from_uuid)
    to_container = nil

    {:ok, _} = ContainerEditor.move_to(revision, from_container, to_container, author, project)

    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("MoveModal.cancel", _, socket) do
    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("show_delete_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project, author: author} = socket.assigns

    case Enum.find(socket.assigns.children, fn r -> r.slug == slug end) do
      %{children: []} = item ->
        case AuthoringResolver.find_hyperlink_references(project.slug, slug) do
          [] ->
            proceed_with_deletion_warning(socket, container, project, author, item)

          references ->
            show_hyperlink_dependency_modal(socket, container, project, references, item)
        end

      item ->
        notify_not_empty(socket, container, project, author, item)
    end
  end

  def handle_event("DeleteModal.delete", %{"slug" => slug}, socket) do
    %{
      modal_assigns: %{
        container: container,
        project: project,
        author: author,
        revision: revision
      }
    } = socket.assigns

    redirect_url = Routes.live_path(socket, __MODULE__, socket.assigns.project.slug)

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

      _ ->
        case ContainerEditor.remove_child(container, project, author, slug) do
          {:ok, _} ->
            {:noreply,
             socket
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

  def handle_event("duplicate_page", %{"id" => page_id}, socket) do
    %{container: container, project: project, author: author} = socket.assigns

    socket =
      case ContainerEditor.duplicate_page(container, page_id, author, project) do
        {:ok, _result} ->
          socket

        {:error, %Ecto.Changeset{} = _changeset} ->
          socket
          |> put_flash(:error, "Could not duplicate page")
      end

    {:noreply,
     assign(socket,
       numberings:
         Numbering.number_full_tree(
           Oli.Publishing.AuthoringResolver,
           socket.assigns.project.slug,
           socket.assigns.project.customizations
         )
     )}
  end

  def handle_event("dismiss", _, socket) do
    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  # handle change of selection
  def handle_event("select", %{"slug" => slug}, socket) do
    selected = Enum.find(socket.assigns.children, fn r -> r.slug == slug end)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("keydown", %{"key" => key, "shiftKey" => shiftKeyPressed?} = params, socket) do
    focused_index =
      case params["index"] do
        nil -> nil
        stringIndex -> String.to_integer(stringIndex)
      end

    last_index = length(socket.assigns.children) - 1
    children = socket.assigns.children

    case {focused_index, key, shiftKeyPressed?} do
      {nil, _, _} ->
        {:noreply, socket}

      {^last_index, "ArrowDown", _} ->
        {:noreply, socket}

      {0, "ArrowUp", _} ->
        {:noreply, socket}

      # Each drop target has a corresponding entry after it with a matching index.
      # That means that the "drop index" is the index of where you'd like to place the item AHEAD OF
      # So to reorder an item below its current position, we add +2 ->
      # +1 would mean insert it BEFORE the next item, but +2 means insert it before the item after the next item.
      # See the logic in container editor that does the adjustment based on the positions of the drop targets.
      {focused_index, "ArrowDown", true} ->
        handle_event(
          "reorder",
          %{
            "sourceIndex" => Integer.to_string(focused_index),
            "dropIndex" => Integer.to_string(focused_index + 2)
          },
          socket
        )

      {focused_index, "ArrowUp", true} ->
        handle_event(
          "reorder",
          %{
            "sourceIndex" => Integer.to_string(focused_index),
            "dropIndex" => Integer.to_string(focused_index - 1)
          },
          socket
        )

      {focused_index, "Enter", _} ->
        {:noreply, assign(socket, :selected, Enum.at(children, focused_index))}

      {_, _, _} ->
        {:noreply, socket}
    end
  end

  # handle reordering event
  def handle_event("reorder", %{"sourceIndex" => source_index, "dropIndex" => index}, socket) do
    source = Enum.at(socket.assigns.children, String.to_integer(source_index))

    socket =
      case ContainerEditor.reorder_child(
             socket.assigns.container,
             socket.assigns.project,
             socket.assigns.author,
             source.slug,
             String.to_integer(index)
           ) do
        {:ok, _} ->
          socket

        {:error, _} ->
          socket
          |> put_flash(:error, "Could not edit page")
      end

    {:noreply, socket}
  end

  # handle drag events
  def handle_event("dragstart", drag_slug, socket) do
    {:noreply, assign(socket, dragging: drag_slug)}
  end

  def handle_event("dragend", _, socket) do
    {:noreply, assign(socket, dragging: nil)}
  end

  def handle_event("add", %{"type" => type, "scored" => scored}, socket) do
    case ContainerEditor.add_new(
           socket.assigns.container,
           type,
           scored,
           socket.assigns.author,
           socket.assigns.project,
           socket.assigns.numberings
         ) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           numberings:
             Numbering.number_full_tree(
               Oli.Publishing.AuthoringResolver,
               socket.assigns.project.slug,
               socket.assigns.project.customizations
             )
         )}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create new item")}
    end
  end

  def handle_event("change-view", params, socket) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, socket.assigns.project.slug, params)
     )}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components
    # that don't need handling (like dropdown toggles)
    Logger.warning("Unhandled event in CurriculumLive: #{inspect(event)}, #{inspect(params)}")
    {:noreply, socket}
  end

  def handle_info({ref, result}, socket) when socket.assigns.import_state.task_ref == ref do
    case result do
      {:ok, revision, warnings} ->
        handle_import_success(socket, revision, warnings)

      {:error, reason, warnings} ->
        handle_import_error(socket, reason, warnings)

      other ->
        handle_import_failure(socket, other)
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket)
      when socket.assigns.import_state.task_ref == ref do
    Process.demonitor(ref, [:flush])

    case reason do
      {:shutdown, {:ok, revision, warnings}} ->
        handle_import_success(socket, revision, warnings)

      {:ok, revision, warnings} ->
        handle_import_success(socket, revision, warnings)

      {:shutdown, {:error, error_reason, warnings}} ->
        handle_import_error(socket, error_reason, warnings)

      {:error, error_reason, warnings} ->
        handle_import_error(socket, error_reason, warnings)

      {:shutdown, error_reason} ->
        handle_import_failure(socket, error_reason)

      other ->
        handle_import_failure(socket, other)
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  # Here we respond to notifications for edits made
  # to the container or to its child children, contained activities and attached objectives
  @impl Phoenix.LiveView
  def handle_info({:updated, revision, _}, socket) do
    socket =
      case Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
        "activity" -> handle_updated_activity(socket, revision)
        "objective" -> handle_updated_objective(socket, revision)
        "page" -> handle_updated_page(socket, revision)
        "container" -> handle_updated_container(socket, revision)
      end

    # redo all subscriptions
    unsubscribe(
      socket.assigns.subscriptions,
      socket.assigns.children,
      socket.assigns.project.slug
    )

    subscriptions =
      subscribe(
        socket.assigns.container,
        socket.assigns.children,
        socket.assigns.rollup,
        socket.assigns.project.slug
      )

    {:noreply, assign(socket, subscriptions: subscriptions)}
  end

  # listens for creation of new objectives
  def handle_info({:new_resource, revision, _}, socket) do
    # include it in our objective map
    rollup = Rollup.objective_updated(socket.assigns.rollup, revision)

    # now listen to it for future edits
    Subscriber.subscribe_to_new_revisions_in_project(
      revision.resource_id,
      socket.assigns.project.slug
    )

    subscriptions = [revision.resource_id | socket.assigns.subscriptions]

    {:noreply, assign(socket, rollup: rollup, subscriptions: subscriptions)}
  end

  def handle_info(
        {:lock_acquired, publication_id, resource_id, author_id},
        %{assigns: %{resources_being_edited: resources_being_edited, project: %{id: project_id}}} =
          socket
      ) do
    # Check to see if the lock_acquired message is intended for this specific project/publication's resource.
    # This check could be optimized by crafting a more specific message that embeds the publication_id, but then the
    # latest active publication_id would need to be tracked in the assigns and updated if a project is published.
    # Same thing applies to the :lock_released handler below.
    if Publishing.get_unpublished_publication_id!(project_id) == publication_id do
      author = Accounts.get_author(author_id)

      new_resources_being_edited = Map.put(resources_being_edited, resource_id, author)
      {:noreply, assign(socket, resources_being_edited: new_resources_being_edited)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:lock_released, publication_id, resource_id},
        %{assigns: %{resources_being_edited: resources_being_edited, project: %{id: project_id}}} =
          socket
      ) do
    if Publishing.get_unpublished_publication_id!(project_id) == publication_id do
      new_resources_being_edited = Map.delete(resources_being_edited, resource_id)
      {:noreply, assign(socket, resources_being_edited: new_resources_being_edited)}
    else
      {:noreply, socket}
    end
  end

  defp new_import_state do
    changeset = import_changeset(%{})

    %{
      show?: false,
      changeset: changeset,
      form: Component.to_form(changeset, as: @import_form_key),
      busy?: false,
      status: :idle,
      task: nil,
      task_ref: nil,
      warnings: [],
      error_message: nil,
      result_revision: nil,
      file_id: nil,
      announcements: []
    }
  end

  defp import_changeset(attrs) do
    {%{file_id: nil}, %{file_id: :string}}
    |> Changeset.cast(attrs, [:file_id])
    |> Changeset.update_change(:file_id, &normalize_file_id/1)
    |> Changeset.validate_required(:file_id,
      message: gettext("Enter the FILE_ID from the Google Docs URL.")
    )
    |> validate_file_id_format()
  end

  defp normalize_file_id(nil), do: nil
  defp normalize_file_id(value) when is_binary(value), do: String.trim(value)
  defp normalize_file_id(value), do: value

  defp validate_file_id_format(%Changeset{} = changeset) do
    file_id = Changeset.get_field(changeset, :file_id)

    if is_nil(file_id) or file_id == "" do
      changeset
    else
      Changeset.validate_change(changeset, :file_id, fn :file_id, value ->
        cond do
          not is_binary(value) ->
            [file_id: gettext("FILE_ID must be text.")]

          value == "" ->
            []

          String.starts_with?(value, "http://") or String.starts_with?(value, "https://") ->
            [
              file_id: gettext("Provide only the FILE_ID portion, not the full Google Docs URL.")
            ]

          Regex.match?(@file_id_pattern, value) ->
            []

          true ->
            [
              file_id:
                gettext(
                  "FILE_ID must be at least 10 characters and may include letters, numbers, hyphen, or underscore."
                )
            ]
        end
      end)
    end
  end

  defp put_import_state(socket, updates) when is_map(updates) do
    state =
      socket.assigns.import_state
      |> Map.merge(updates)
      |> maybe_put_form(updates)

    assign(socket, import_state: state)
  end

  defp hide_import_modal(socket) do
    socket
    |> assign(import_state: new_import_state())
    |> push_event("js-exec", %{
      to: "#google-docs-import-modal-hide",
      attr: "data-hide_modal"
    })
  end

  defp maybe_put_form(state, updates) do
    if Map.has_key?(updates, :changeset) do
      Map.put(state, :form, Component.to_form(state.changeset, as: @import_form_key))
    else
      state
    end
  end

  defp push_announcement(socket, message) when message in [nil, ""], do: socket

  defp push_announcement(socket, message) do
    trimmed = String.trim(message || "")

    if trimmed == "" do
      socket
    else
      assign(socket,
        import_state: %{
          socket.assigns.import_state
          | announcements: add_announcement(socket.assigns.import_state.announcements, trimmed)
        }
      )
    end
  end

  defp add_announcement(announcements, message) do
    (announcements ++ [message])
    |> Enum.take(-3)
  end

  defp resolve_importer do
    config = importer_config()
    {Keyword.get(config, :importer, Import), Keyword.delete(config, :importer)}
  end

  defp importer_config do
    Application.get_env(:oli, :google_docs_import, [])
  end

  defp can_import?(author) do
    Accounts.is_admin?(author) || Accounts.has_admin_role?(author, :content_admin)
  end

  defp revision_slug(%Revision{slug: slug}) when is_binary(slug) and slug != "", do: slug
  defp revision_slug(%{slug: slug}) when is_binary(slug) and slug != "", do: slug
  defp revision_slug(_), do: nil

  defp present_title(title) when is_binary(title) and title != "", do: title
  defp present_title(_), do: gettext("Untitled page")

  defp success_flash_message(%Revision{} = revision, warnings) do
    title = present_title(revision.title)

    case length(warnings) do
      0 ->
        gettext("Imported \"%{title}\" from Google Docs.", title: title)

      count ->
        gettext(
          "Imported \"%{title}\" with %{count} warning(s). Review details in the dialog.",
          title: title,
          count: count
        )
    end
  end

  defp translate_import_error({:invalid_file_id, :blank}) do
    gettext("FILE_ID cannot be blank.")
  end

  defp translate_import_error({:invalid_file_id, :format}) do
    gettext("FILE_ID looks invalid. Use the value between `/d/` and `/` in the Google Docs URL.")
  end

  defp translate_import_error({:invalid_file_id, :not_binary}) do
    gettext("FILE_ID must be text.")
  end

  defp translate_import_error({:http_status, status, _}) do
    gettext(
      "Google Docs returned HTTP %{status}. Check sharing permissions and try again.",
      status: status
    )
  end

  defp translate_import_error({:http_redirect, status, location}) do
    gettext(
      "Google Docs redirected the request (HTTP %{status}) to %{location}. Update the document sharing settings and use the FILE_ID (not the share link).",
      status: status,
      location: location || gettext("an unknown URL")
    )
  end

  defp translate_import_error({:http_error, reason}) do
    gettext("Google Docs request failed: %{reason}.", reason: inspect(reason))
  end

  defp translate_import_error({:body_too_large, %{limit: limit}}) do
    mb = limit_mb(limit)

    gettext("The exported Markdown exceeded the %{limit} MB limit.", limit: mb)
  end

  defp translate_import_error({:body_too_large, %{bytes: bytes}}) do
    gettext("The exported Markdown is %{bytes} bytes and exceeds the allowed size.", bytes: bytes)
  end

  defp translate_import_error(:import_in_progress) do
    gettext("An import for this document is already running. Please wait for it to finish.")
  end

  defp translate_import_error({:not_found, _}) do
    gettext("Project could not be found.")
  end

  defp translate_import_error({:not_authorized}) do
    gettext("You do not have permission to import into this project.")
  end

  defp translate_import_error(:document_too_complex) do
    gettext("The document could not be imported because it is too complex.")
  end

  defp translate_import_error({:document_too_complex, _}) do
    gettext("The document could not be imported because it is too complex.")
  end

  defp translate_import_error(other) do
    gettext("Import failed: %{reason}.", reason: inspect(other))
  end

  defp limit_mb(nil), do: nil

  defp limit_mb(limit) when is_integer(limit) do
    (limit / 1_048_576)
    |> Float.round(1)
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp limit_mb(limit), do: limit

  defp normalize_warnings(nil), do: []
  defp normalize_warnings([]), do: []

  defp normalize_warnings(warnings) when is_list(warnings) do
    Enum.map(warnings, &normalize_warning/1)
  end

  defp normalize_warnings(_), do: []

  defp normalize_warning(%{message: message} = warning) do
    %{
      code: Map.get(warning, :code),
      message: message,
      severity: Map.get(warning, :severity, :warn),
      metadata: Map.get(warning, :metadata, %{})
    }
  end

  defp normalize_warning(%{code: code, metadata: metadata}) do
    Warnings.build(code, metadata || %{})
  end

  defp normalize_warning(other) when is_map(other) do
    message = Map.get(other, :message) || inspect(other)
    severity = Map.get(other, :severity, :warn)

    %{
      code: Map.get(other, :code),
      message: message,
      severity: severity,
      metadata: Map.get(other, :metadata, %{})
    }
  end

  defp normalize_warning(other) do
    %{
      code: nil,
      message: inspect(other),
      severity: :warn,
      metadata: %{}
    }
  end

  defp handle_import_success(socket, revision, warnings) do
    normalized_warnings = normalize_warnings(warnings)
    title = present_title(revision.title)

    socket =
      socket
      |> put_import_state(%{
        busy?: false,
        status: :success,
        task: nil,
        task_ref: nil,
        warnings: normalized_warnings,
        error_message: nil,
        result_revision: revision,
        show?: true
      })
      |> put_flash(:info, success_flash_message(revision, normalized_warnings))
      |> push_announcement(gettext("Imported \"%{title}\" successfully.", title: title))

    {:noreply, socket}
  end

  defp handle_import_error(socket, reason, warnings) do
    normalized_warnings = normalize_warnings(warnings)
    message = translate_import_error(reason)

    socket =
      socket
      |> put_import_state(%{
        busy?: false,
        status: :error,
        task: nil,
        task_ref: nil,
        warnings: normalized_warnings,
        error_message: message,
        result_revision: nil,
        show?: true
      })
      |> put_flash(:error, message)
      |> push_announcement(message)

    {:noreply, socket}
  end

  defp handle_import_failure(socket, reason) do
    message = translate_import_error(reason)

    socket =
      socket
      |> put_import_state(%{
        busy?: false,
        status: :error,
        task: nil,
        task_ref: nil,
        warnings: [],
        error_message: message,
        result_revision: nil,
        show?: true
      })
      |> put_flash(:error, message)
      |> push_announcement(message)

    {:noreply, socket}
  end

  defp warning_label(:error), do: gettext("Error")
  defp warning_label(:warn), do: gettext("Warning")
  defp warning_label(:info), do: gettext("Info")
  defp warning_label(_), do: gettext("Info")

  defp warning_badge_class(:error), do: "bg-red-100 text-red-800"
  defp warning_badge_class(:warn), do: "bg-amber-100 text-amber-900"
  defp warning_badge_class(:info), do: "bg-blue-100 text-blue-800"
  defp warning_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp warning_container_class(:error), do: "border-red-200 bg-red-50"
  defp warning_container_class(:warn), do: "border-amber-200 bg-amber-50"
  defp warning_container_class(:info), do: "border-blue-200 bg-blue-50"
  defp warning_container_class(_), do: "border-gray-200 bg-gray-50"

  # Load either a specific container, or if the slug is nil the root. After loaded,
  # scrub the container's children to ensure that there a no duplicate ids that may
  # have crept in.
  defp load_and_scrub_container(container_slug, project_slug, root_container) do
    container =
      if is_nil(container_slug) do
        root_container
      else
        AuthoringResolver.from_revision_slug(project_slug, container_slug)
      end

    {deduped, _} =
      Enum.reduce(container.children, {[], MapSet.new()}, fn id, {all, map} ->
        case MapSet.member?(map, id) do
          true -> {all, map}
          false -> {[id | all], MapSet.put(map, id)}
        end
      end)

    # Now see if the deduping actually led to any change in the number of children,
    # remembering though that the deduped children ids are in reverse order.
    if length(deduped) != length(container.children) do
      Repo.transaction(fn ->
        ChangeTracker.track_revision(project_slug, container, %{
          # restore correct order
          children: Enum.reverse(deduped)
        })
      end)
    else
      {:ok, container}
    end
  end

  defp apply_action(socket, :edit, %{"project_id" => project_id, "revision_slug" => revision_slug}) do
    socket
    |> assign(:page_title, "Options")
    |> assign(:revision, AuthoringResolver.from_revision_slug(project_id, revision_slug))
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Curriculum | " <> socket.assigns.project.title)
    |> assign(:revision, nil)
  end

  # spin up subscriptions for the container and for all of its children, activities and attached objectives
  defp subscribe(
         container,
         children,
         %Rollup{activity_map: activity_map, objective_map: objective_map},
         project_slug
       ) do
    Enum.each(children, fn child ->
      Subscriber.subscribe_to_locks_acquired(project_slug, child.resource_id)
      Subscriber.subscribe_to_locks_released(project_slug, child.resource_id)
    end)

    activity_ids = Enum.map(activity_map, fn {id, _} -> id end)
    objective_ids = Enum.map(objective_map, fn {id, _} -> id end)

    ids =
      [container.resource_id] ++
        Enum.map(children, fn c -> c.resource_id end) ++ activity_ids ++ objective_ids

    Enum.each(ids, fn id ->
      Subscriber.subscribe_to_new_revisions_in_project(id, project_slug)
    end)

    Subscriber.subscribe_to_new_resources_of_type(
      Oli.Resources.ResourceType.id_for_objective(),
      project_slug
    )

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, children, project_slug) do
    Subscriber.unsubscribe_to_new_resources_of_type(
      Oli.Resources.ResourceType.id_for_objective(),
      project_slug
    )

    Enum.each(ids, &Subscriber.unsubscribe_to_new_revisions_in_project(&1, project_slug))

    Enum.each(children, fn child ->
      Subscriber.unsubscribe_to_locks_acquired(project_slug, child.resource_id)
      Subscriber.unsubscribe_to_locks_released(project_slug, child.resource_id)
    end)
  end

  defp proceed_with_deletion_warning(socket, container, project, author, item) do
    modal_assigns = %{
      id: "delete_#{item.slug}",
      redirect_url: Routes.live_path(socket, __MODULE__, project.slug, container.slug),
      revision: item,
      container: container,
      project: project,
      author: author
    }

    modal = fn assigns ->
      ~H"""
      <DeleteModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  defp show_hyperlink_dependency_modal(socket, container, project, hyperlinks, item) do
    modal_assigns = %{
      id: "not_empty_#{item.slug}",
      revision: item,
      container: container,
      project: project,
      hyperlinks: hyperlinks
    }

    modal = fn assigns ->
      ~H"""
      <HyperlinkDependencyModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  defp notify_not_empty(socket, container, project, author, item) do
    modal_assigns = %{
      id: "not_empty_#{item.slug}",
      revision: item,
      container: container,
      project: project,
      author: author
    }

    modal = fn assigns ->
      ~H"""
      <NotEmptyModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  defp update_author_view_pref(author, curriculum_view) do
    updated_preferences =
      value_or(author.preferences, %Accounts.AuthorPreferences{})
      |> Map.put(:curriculum_view, curriculum_view)
      |> Map.from_struct()

    Accounts.update_author(author, %{preferences: updated_preferences})
  end

  defp has_renderable_change?(page1, page2) do
    page1.title != page2.title or
      page1.graded != page2.graded or
      page1.max_attempts != page2.max_attempts or
      page1.scoring_strategy_id != page2.scoring_strategy_id
  end

  # We need to monitor for changes in the title of an objective
  defp handle_updated_objective(socket, revision) do
    assign(socket, rollup: Rollup.objective_updated(socket.assigns.rollup, revision))
  end

  # We need to monitor for changes in the title of an objective
  defp handle_updated_activity(socket, revision) do
    assign(socket,
      rollup:
        Rollup.activity_updated(socket.assigns.rollup, revision, socket.assigns.project.slug)
    )
  end

  defp handle_updated_page(socket, revision) do
    id = revision.resource_id

    old_page =
      Enum.find(socket.assigns.children, fn p -> p.resource_id == revision.resource_id end)

    # check to see if the activities in that page have changed since our last view of it
    {:ok, activities_delta} = ActivityDelta.new(revision, old_page)

    # We only track this update if it affects our rendering.  So we check to see if the
    # title or settings has changed of if the activities in this page haven't been added/removed
    if has_renderable_change?(old_page, revision) or
         ActivityDelta.have_activities_changed?(activities_delta) do
      # we splice that page into its location
      children =
        case Enum.find_index(socket.assigns.children, fn p -> p.resource_id == id end) do
          nil -> socket.assigns.children
          index -> List.replace_at(socket.assigns.children, index, revision)
        end

      # update our selection to reflect the latest model
      selected =
        case socket.assigns.selected do
          nil -> nil
          s -> Enum.find(children, fn r -> r.resource_id == s.resource_id end)
        end

      # update the relevant maps that allow us to show roll ups
      rollup =
        Rollup.page_updated(
          socket.assigns.rollup,
          revision,
          activities_delta,
          socket.assigns.project.slug
        )

      assign(socket, selected: selected, children: children, rollup: rollup)
    else
      socket
    end
  end

  defp handle_updated_container(socket, revision) do
    %{container: %Revision{resource_id: container_resource_id}} = socket.assigns

    # only update when the container that changed is the container in view
    if revision.resource_id == container_resource_id do
      # in the case of a change to the container, we simplify by just pulling a new view of
      # the container and its contents. This handles addition, removal, reordering from the
      # local user as well as a collaborator
      children = ContainerEditor.list_all_container_children(revision, socket.assigns.project)

      {:ok, rollup} = Rollup.new(children, socket.assigns.project.slug)

      selected =
        case socket.assigns.selected do
          nil -> nil
          s -> Enum.find(children, fn r -> r.resource_id == s.resource_id end)
        end

      assign(socket,
        selected: selected,
        container: revision,
        children: children,
        rollup: rollup,
        numberings:
          Numbering.number_full_tree(
            Oli.Publishing.AuthoringResolver,
            socket.assigns.project.slug,
            socket.assigns.project.customizations
          )
      )
    else
      socket
    end
  end

  # Resources currently being edited by an author (has a lock present)
  # : %{ resource_id => author }
  defp get_resources_being_edited(resource_ids, project_id) do
    project_id
    |> Publishing.get_unpublished_publication_id!()
    |> (&Publishing.retrieve_lock_info(resource_ids, &1)).()
    |> Enum.map(fn published_resource ->
      {published_resource.resource_id, published_resource.author}
    end)
    |> Enum.into(%{})
  end
end
