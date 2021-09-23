defmodule OliWeb.Delivery.RemixSection do
  use OliWeb, :live_view

  import OliWeb.ViewHelpers,
    only: [
      is_section_instructor_or_admin?: 2
    ]

  import OliWeb.Curriculum.Utils,
    only: [
      is_container?: 1
    ]

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts

  alias OliWeb.Delivery.Remix.{
    DropTarget,
    Entry
  }

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Numbering
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Delivery.Remix.{RemoveModal, MoveModal}

  def mount(
        _params,
        %{
          "section_slug" => section_slug,
          "current_user_id" => current_user_id
        } = session,
        socket
      ) do
    section = Sections.get_section_by_slug(section_slug)

    redirect_after_save =
      Map.get(
        session,
        "redirect_after_save",
        Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)
      )

    if section.open_and_free do
      current_author = Map.get(session, "current_author")

      # only permit authoring admin level access
      if Accounts.is_admin?(current_author) do
        init_state(socket, section, redirect_after_save)
      else
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
      end
    else
      # only permit instructor or admin level access
      current_user =
        Accounts.get_user!(current_user_id, preload: [:platform_roles, :author])
        |> Repo.preload([:platform_roles, :author])

      if is_section_instructor_or_admin?(section.slug, current_user) do
        init_state(socket, section, redirect_after_save)
      else
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
      end
    end
  end

  def mount(
        %{
          "section_slug" => section_slug
        },
        %{
          "current_author_id" => current_author_id
        } = session,
        socket
      ) do
    section = Sections.get_section_by_slug(section_slug)

    redirect_after_save = Routes.live_path(socket, OliWeb.Products.DetailsView, section_slug)

    if Oli.Delivery.Sections.Blueprint.is_author_of_blueprint?(section_slug, current_author_id) do
      init_state(socket, section, redirect_after_save)
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  def init_state(socket, section, redirect_after_save) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    {:ok,
     assign(socket,
       title: "Customize Content",
       section: section,
       previous_hierarchy: hierarchy,
       hierarchy: hierarchy,
       active: hierarchy,
       dragging: nil,
       selected: nil,
       has_unsaved_changes: false,
       modal: nil,
       redirect_after_save: redirect_after_save
     )}
  end

  # handle change of selection
  def handle_event("select", %{"slug" => slug}, socket) do
    selected =
      Enum.find(socket.assigns.active.children, fn node ->
        node.slug == slug
      end)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("set_active", %{"slug" => slug}, socket) do
    %{hierarchy: hierarchy} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, slug)

    if is_container?(active.revision) do
      {:noreply, assign(socket, :active, active)}
    else
      # do nothing
      {:noreply, socket}
    end
  end

  def handle_event("keydown", %{"key" => key, "shiftKey" => shiftKeyPressed?} = params, socket) do
    %{active: active} = socket.assigns

    focused_index =
      case params["index"] do
        nil -> nil
        stringIndex -> String.to_integer(stringIndex)
      end

    last_index = length(active.children) - 1

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
        {:noreply, assign(socket, :selected, Enum.at(active.children, focused_index))}

      {_, _, _} ->
        {:noreply, socket}
    end
  end

  # handle reordering event
  def handle_event("reorder", %{"sourceIndex" => source_index, "dropIndex" => drop_index}, socket) do
    %{active: active, hierarchy: hierarchy} = socket.assigns

    source_index = String.to_integer(source_index)
    destination_index = String.to_integer(drop_index)

    node = Enum.at(active.children, source_index)

    children =
      Hierarchy.reorder_children(
        active.children,
        node,
        source_index,
        destination_index
      )

    updated = %HierarchyNode{active | children: children}
    hierarchy = Hierarchy.find_and_update_node(hierarchy, updated)

    {hierarchy, _numberings} = Numbering.renumber_hierarchy(hierarchy)

    {:noreply, assign(socket, hierarchy: hierarchy, active: updated, has_unsaved_changes: true)}
  end

  # handle drag events
  def handle_event("dragstart", drag_slug, socket) do
    {:noreply, assign(socket, dragging: drag_slug)}
  end

  def handle_event("dragend", _, socket) do
    {:noreply, assign(socket, dragging: nil)}
  end

  def handle_event("cancel", _, socket) do
    %{redirect_after_save: redirect_after_save} = socket.assigns

    {:noreply,
     redirect(socket,
       to: redirect_after_save
     )}
  end

  def handle_event("save", _, socket) do
    %{section: section, hierarchy: hierarchy, redirect_after_save: redirect_after_save} =
      socket.assigns

    Sections.rebuild_section_curriculum(section, hierarchy)

    {:noreply, redirect(socket, to: redirect_after_save)}
  end

  def handle_event("show_move_modal", %{"slug" => slug}, socket) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, slug)

    assigns = %{
      id: "move_#{slug}",
      node: node,
      old_container: active,
      container: active,
      breadcrumbs: breadcrumb_trail_to(hierarchy, active),
      selection: nil
    }

    {:noreply,
     assign(socket,
       modal: %{component: MoveModal, assigns: assigns}
     )}
  end

  def handle_event("HierarchyPicker.update_selection", %{"slug" => slug}, socket) do
    %{hierarchy: hierarchy, modal: modal} = socket.assigns

    container = Hierarchy.find_in_hierarchy(hierarchy, slug)
    breadcrumbs = breadcrumb_trail_to(hierarchy, container)

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | container: container,
            selection: slug,
            breadcrumbs: breadcrumbs
        }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "MoveModal.move_item",
        %{"slug" => slug, "selection" => selection},
        socket
      ) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, slug)
    hierarchy = Hierarchy.move_node(hierarchy, node, selection)

    # refresh active node
    active = Hierarchy.find_in_hierarchy(hierarchy, active.slug)

    {:noreply, assign(socket, hierarchy: hierarchy, active: active, has_unsaved_changes: true)}
  end

  def handle_event("MoveModal.cancel", _, socket) do
    {:noreply, socket}
  end

  def handle_event("show_remove_modal", %{"slug" => slug}, socket) do
    %{hierarchy: hierarchy} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, slug)

    assigns = %{
      id: "remove_#{slug}",
      node: node
    }

    {:noreply,
     assign(socket,
       modal: %{component: RemoveModal, assigns: assigns}
     )}
  end

  def handle_event("RemoveModal.remove", %{"slug" => slug}, socket) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    hierarchy = Hierarchy.find_and_remove_node(hierarchy, slug)

    # refresh active node
    active = Hierarchy.find_in_hierarchy(hierarchy, active.slug)

    {:noreply, assign(socket, hierarchy: hierarchy, active: active, has_unsaved_changes: true)}
  end

  def handle_event("RemoveModal.cancel", _, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  defp new_container_name(%HierarchyNode{section_resource: sr} = _active) do
    Numbering.container_type(sr.numbering_level + 1)
  end

  defp render_breadcrumb(assigns) do
    %{hierarchy: hierarchy, active: active} = assigns
    breadcrumbs = breadcrumb_trail_to(hierarchy, active)

    ~L"""
      <div class="breadcrumb custom-breadcrumb p-1 px-2">
        <button id="curriculum-back" class="btn btn-sm btn-link" phx-click="set_active" phx-value-slug="<%= previous_slug(breadcrumbs) %>"><i class="las la-arrow-left"></i></button>

        <%= for {breadcrumb, index} <- Enum.with_index(breadcrumbs) do %>
          <%= render_breadcrumb_item Enum.into(%{
            breadcrumb: breadcrumb,
            show_short: length(breadcrumbs) > 3,
            is_last: length(breadcrumbs) - 1 == index,
           }, assigns) %>
        <% end %>
      </div>
    """
  end

  defp render_breadcrumb_item(
         %{breadcrumb: breadcrumb, show_short: show_short, is_last: is_last} = assigns
       ) do
    ~L"""
    <button class="breadcrumb-item btn btn-xs btn-link pl-0 pr-8" <%= if is_last, do: "disabled" %> phx-click="set_active" phx-value-slug="<%= breadcrumb.slug %>">
      <%= get_title(breadcrumb, show_short) %>
    </button>
    """
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  defp previous_slug(breadcrumbs) do
    previous = Enum.at(breadcrumbs, length(breadcrumbs) - 2)
    previous.slug
  end

  def breadcrumb_trail_to(hierarchy, active) do
    [
      Breadcrumb.new(%{
        full_title: "Curriculum",
        slug: hierarchy.section_resource.slug
      })
      | trail_to_helper(hierarchy, active)
    ]
  end

  defp trail_to_helper(hierarchy, active) do
    with {:ok, [_root | path]} =
           Numbering.path_from_root_to(
             hierarchy,
             active
           ) do
      Enum.map(path, fn node ->
        make_breadcrumb(node)
      end)
    end
  end

  defp make_breadcrumb(%HierarchyNode{slug: slug, revision: rev, numbering: numbering}) do
    case rev.resource_type do
      "container" ->
        Breadcrumb.new(%{
          full_title:
            Numbering.prefix(%{level: numbering.level, index: numbering.index}) <>
              ": " <> rev.title,
          short_title: Numbering.prefix(%{level: numbering.level, index: numbering.index}),
          slug: slug
        })

      _ ->
        Breadcrumb.new(%{
          full_title: rev.title,
          slug: slug
        })
    end
  end
end
