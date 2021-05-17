defmodule OliWeb.Curriculum.ContainerLive do
  @moduledoc """
  LiveView implementation of a container editor.
  """

  use OliWeb, :live_view

  import Oli.Utils, only: [value_or: 2]

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Course

  alias OliWeb.Curriculum.{
    Rollup,
    ActivityDelta,
    DropTarget,
    EntryLive,
    OptionsModal,
    MoveModal,
    DeleteModal
  }

  alias Oli.Resources.ScoringStrategy
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Oli.Publishing
  alias Oli.Accounts
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Resources.Numbering
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb

  def mount(
        %{"project_id" => project_slug} = params,
        %{"current_author_id" => author_id},
        socket
      ) do
    root_container = AuthoringResolver.root_container(project_slug)
    container_slug = Map.get(params, "container_slug")

    project = Course.get_project_by_slug(project_slug)

    cond do
      # Explicitly routing to root_container, strip off the container param
      container_slug == root_container.slug && socket.assigns.live_action == :index ->
        {:ok, redirect(socket, to: Routes.container_path(socket, :index, project_slug))}

      # Routing to missing container
      container_slug && is_nil(AuthoringResolver.from_revision_slug(project_slug, container_slug)) ->
        {:ok,
         redirect(socket, to: Routes.resource_path(socket, :edit, project_slug, container_slug))}

      # Implicitly routing to root container or explicitly routing to sub-container
      true ->
        container =
          if is_nil(container_slug) do
            root_container
          else
            AuthoringResolver.from_revision_slug(project_slug, container_slug)
          end

        children = ContainerEditor.list_all_container_children(container, project)

        {:ok, rollup} = Rollup.new(children, project.slug)

        subscriptions = subscribe(container, children, rollup, project.slug)

        author = Repo.get(Author, author_id)

        view_pref =
          case author.preferences do
            %{curriculum_view: curriculum_view} ->
              curriculum_view

            _ ->
              "Basic"
          end

        {:ok,
         assign(socket,
           children: children,
           active: :curriculum,
           breadcrumbs: Breadcrumb.trail_to(project_slug, container.slug),
           adaptivity_flag: Oli.Features.enabled?("adaptivity"),
           rollup: rollup,
           container: container,
           project: project,
           subscriptions: subscriptions,
           author: author,
           view: view_pref,
           selected: nil,
           modal: nil,
           resources_being_edited: get_resources_being_edited(container.children, project.id),
           numberings: Numbering.number_full_tree(Oli.Publishing.AuthoringResolver, project_slug),
           dragging: nil
         )}
    end
  end

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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Curriculum")
    |> assign(:revision, nil)
  end

  defp apply_action(socket, :edit, %{"project_id" => project_id, "revision_slug" => revision_slug}) do
    socket
    |> assign(:page_title, "Options")
    |> assign(:revision, AuthoringResolver.from_revision_slug(project_id, revision_slug))
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
      Oli.Resources.ResourceType.get_id_by_type("objective"),
      project_slug
    )

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, children, project_slug) do
    Subscriber.unsubscribe_to_new_resources_of_type(
      Oli.Resources.ResourceType.get_id_by_type("objective"),
      project_slug
    )

    Enum.each(ids, &Subscriber.unsubscribe_to_new_revisions_in_project(&1, project_slug))

    Enum.each(children, fn child ->
      Subscriber.unsubscribe_to_locks_acquired(project_slug, child.resource_id)
      Subscriber.unsubscribe_to_locks_released(project_slug, child.resource_id)
    end)
  end

  def handle_event("HierarchyPicker.select", %{"slug" => slug}, socket) do
    %{modal: %{assigns: %{project: project} = modal_assigns}} = socket.assigns

    container =
      case slug do
        "" ->
          AuthoringResolver.root_container(project.slug)

        slug ->
          AuthoringResolver.from_revision_slug(project.slug, slug)
      end

    children = ContainerEditor.list_all_container_children(container, project)
    breadcrumbs = Breadcrumb.trail_to(project.slug, container.slug)

    modal_assigns =
      modal_assigns
      |> put_in([:container], container)
      |> put_in([:children], children)
      |> put_in([:breadcrumbs], breadcrumbs)
      |> put_in([:selection], container.slug)

    {:noreply, update_modal_assigns(socket, modal_assigns)}
  end

  def handle_event("move_item", %{"selection" => _selection}, socket) do
    %{
      modal: %{
        assigns: %{
          project: project,
          revision: revision,
          old_container: old_container,
          container: new_container
        }
      },
      author: author
    } = socket.assigns

    {:ok, _} = ContainerEditor.move_to(revision, old_container, new_container, author, project)

    {:noreply, assign(socket, modal: nil)}
  end

  def handle_event("show_options_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project} = socket.assigns

    assigns = %{
      id: "options_#{slug}",
      container: container,
      revision: Enum.find(socket.assigns.children, fn r -> r.slug == slug end),
      project: project
    }

    {:noreply,
     assign(socket,
       modal: %{component: OptionsModal, assigns: assigns}
     )}
  end

  def handle_event("show_move_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project} = socket.assigns

    assigns = %{
      id: "move_#{slug}",
      revision: Enum.find(socket.assigns.children, fn r -> r.slug == slug end),
      old_container: container,
      container: container,
      project: project,
      breadcrumbs: Breadcrumb.trail_to(project.slug, container.slug),
      children: ContainerEditor.list_all_container_children(container, project),
      numberings: Numbering.number_full_tree(AuthoringResolver, project.slug),
      selection: nil
    }

    {:noreply,
     assign(socket,
       modal: %{component: MoveModal, assigns: assigns}
     )}
  end

  def handle_event("show_delete_modal", %{"slug" => slug}, socket) do
    %{container: container, project: project, author: author} = socket.assigns

    assigns = %{
      id: "delete_#{slug}",
      revision: Enum.find(socket.assigns.children, fn r -> r.slug == slug end),
      container: container,
      project: project,
      author: author
    }

    {:noreply,
     assign(socket,
       modal: %{component: DeleteModal, assigns: assigns}
     )}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  # handle any cancel events a modal might generate from being closed
  def handle_event("cancel_modal", params, socket), do: handle_event("cancel", params, socket)

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

  # handle clicking of the "Add Graded Assessment" or "Add Practice Page" buttons
  def handle_event("add", %{"type" => type}, socket) do
    attrs = %{
      objectives: %{"attached" => []},
      children: [],
      content:
        case type do
          "Adaptive" ->
            %{
              "model" => [],
              "advancedAuthoring" => true,
              "advancedDelivery" => true,
              "displayApplicationChrome" => false
            }

          _ ->
            %{"model" => []}
        end,
      title:
        case type do
          "Adaptive" -> "New Adaptive Page"
          "Scored" -> "New Assessment"
          "Unscored" -> "New Page"
          "Container" -> new_container_name(socket.assigns.numberings, socket.assigns.container)
        end,
      graded:
        case type do
          "Adaptive" -> false
          "Scored" -> true
          "Unscored" -> false
          "Container" -> false
        end,
      max_attempts:
        case type do
          "Adaptive" -> 0
          "Scored" -> 5
          "Unscored" -> 0
          "Container" -> nil
        end,
      recommended_attempts:
        case type do
          "Adaptive" -> 0
          "Scored" -> 5
          "Unscored" -> 0
          "Container" -> nil
        end,
      scoring_strategy_id:
        case type do
          "Adaptive" -> ScoringStrategy.get_id_by_type("best")
          "Scored" -> ScoringStrategy.get_id_by_type("best")
          "Unscored" -> ScoringStrategy.get_id_by_type("best")
          "Container" -> nil
        end,
      resource_type_id:
        case type do
          "Adaptive" -> Oli.Resources.ResourceType.get_id_by_type("page")
          "Scored" -> Oli.Resources.ResourceType.get_id_by_type("page")
          "Unscored" -> Oli.Resources.ResourceType.get_id_by_type("page")
          "Container" -> Oli.Resources.ResourceType.get_id_by_type("container")
        end
    }

    socket =
      case ContainerEditor.add_new(
             socket.assigns.container,
             attrs,
             socket.assigns.author,
             socket.assigns.project
           ) do
        {:ok, _} ->
          socket

        {:error, %Ecto.Changeset{} = _changeset} ->
          socket
          |> put_flash(:error, "Could not create new item")
      end

    {:noreply,
     assign(socket,
       numberings:
         Numbering.number_full_tree(Oli.Publishing.AuthoringResolver, socket.assigns.project.slug)
     )}
  end

  def handle_event("change-view", %{"view" => view}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.container_path(
           socket,
           :index,
           socket.assigns.project.slug,
           socket.assigns.container.slug,
           %{view: view}
         )
     )}
  end

  defp update_author_view_pref(author, curriculum_view) do
    updated_preferences =
      value_or(author.preferences, %Accounts.AuthorPreferences{})
      |> Map.put(:curriculum_view, curriculum_view)
      |> Map.from_struct()

    Accounts.update_author(author, %{preferences: updated_preferences})
  end

  defp update_modal_assigns(socket, updated_assigns) do
    %{modal: %{assigns: assigns} = modal} = socket.assigns

    modal =
      modal
      |> put_in([:assigns], Enum.into(updated_assigns, assigns))

    assign(socket, modal: modal)
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
    # in the case of a change to the container, we simplify by just pulling a new view of
    # the container and its contents. This handles addition, removal, reordering from the
    # local user as well as a collaborator
    children = ContainerEditor.list_all_container_children(revision, socket.assigns.project)

    {:ok, rollup} = Rollup.new(children, socket.assigns.project.slug)

    numberings =
      Numbering.number_full_tree(Oli.Publishing.AuthoringResolver, socket.assigns.project.slug)

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
      numberings: numberings
    )
  end

  # Here we respond to notifications for edits made
  # to the container or to its child children, contained activities and attached objectives
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
      author =
        Accounts.get_user!(author_id)
        |> Repo.preload(:author)

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

  # Resources currently being edited by an author (has a lock present)
  # : %{ resource_id => author }
  def get_resources_being_edited(resource_ids, project_id) do
    project_id
    |> Publishing.get_unpublished_publication_id!()
    |> (&Publishing.retrieve_lock_info(resource_ids, &1)).()
    |> Enum.map(fn published_resource ->
      {published_resource.resource_id, published_resource.author}
    end)
    |> Enum.into(%{})
  end

  def new_container_name(numberings, parent_container) do
    numbering = Map.get(numberings, parent_container.id)

    if numbering do
      Numbering.container_type(numbering.level + 1)
    else
      "Unit"
    end
  end
end
