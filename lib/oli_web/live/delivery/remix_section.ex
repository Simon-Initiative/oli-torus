defmodule OliWeb.Delivery.RemixSection do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

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
  alias OliWeb.Delivery.Remix.{RemoveModal, AddMaterialsModal}
  alias OliWeb.Common.Hierarchy.MoveModal
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias OliWeb.Sections.Mount

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Cusomize Content",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(
        %{
          "section_slug" => section_slug
        },
        session,
        socket
      ) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:admin, _, section} ->
        cond do
          section.open_and_free ->
            mount_as_open_and_free(socket, section, session)

          section.type == :blueprint ->
            mount_as_product_creator(socket, section, session)

          true ->
            mount_as_instructor(socket, section, session)
        end

      {:user, _, section} ->
        mount_as_instructor(socket, section, session)

      {:author, _, section} ->
        mount_as_product_creator(socket, section, session)
    end
  end

  def mount_as_instructor(socket, section, %{"current_user_id" => current_user_id} = _session) do
    current_user = Accounts.get_user!(current_user_id, preload: [:platform_roles, :author])

    redirect_after_save = Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)

    section =
      section
      |> Repo.preload(:institution)

    available_publications =
      Publishing.retrieve_visible_publications(current_user, section.institution)

    # only permit instructor or admin level access

    init_state(socket,
      breadcrumbs: set_breadcrumbs(:user, section),
      section: section,
      redirect_after_save: redirect_after_save,
      available_publications: available_publications
    )
  end

  def mount_as_instructor(socket, section, %{"current_author_id" => current_author_id} = _session) do
    author = Accounts.get_author!(current_author_id)

    redirect_after_save = Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)

    section =
      section
      |> Repo.preload(:institution)

    available_publications = Publishing.available_publications(author, section.institution)

    # only permit instructor or admin level access

    init_state(socket,
      breadcrumbs: set_breadcrumbs(:user, section),
      section: section,
      redirect_after_save: redirect_after_save,
      available_publications: available_publications
    )
  end

  def mount_as_open_and_free(
        socket,
        section,
        _session
      ) do
    redirect_after_save = OliWeb.OpenAndFreeView.get_path([:admin, :show, section])

    # only permit authoring admin level access

    init_state(socket,
      breadcrumbs: set_breadcrumbs(:admin, section),
      section: section,
      redirect_after_save: redirect_after_save,
      available_publications: Publishing.all_available_publications()
    )
  end

  def mount_as_product_creator(
        socket,
        section,
        %{"current_author_id" => current_author_id} = _session
      ) do
    current_author = Accounts.get_author!(current_author_id)
    redirect_after_save = Routes.live_path(socket, OliWeb.Products.DetailsView, section.slug)

    if Oli.Delivery.Sections.Blueprint.is_author_of_blueprint?(section.slug, current_author_id) or
         Accounts.is_admin?(current_author) do
      init_state(socket,
        breadcrumbs: set_breadcrumbs(:user, section),
        section: section,
        redirect_after_save: redirect_after_save,
        available_publications: Publishing.all_available_publications()
      )
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  def init_state(socket, opts) do
    section = Keyword.get(opts, :section)
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    redirect_after_save = Keyword.get(opts, :redirect_after_save)
    breadcrumbs = Keyword.get(opts, :breadcrumbs)
    available_publications = Keyword.get(opts, :available_publications)
    pinned_project_publications = Sections.get_pinned_project_publications(section.id)

    # replace any of the latest available publications that are already pinned with the
    # pinned publication
    available_publications =
      Enum.map(available_publications, fn pub ->
        case pinned_project_publications[pub.project_id] do
          nil ->
            pub

          pinned ->
            pinned
        end
      end)

    {:ok,
     assign(socket,
       title: "Customize Content",
       section: section,
       pinned_project_publications: pinned_project_publications,
       previous_hierarchy: hierarchy,
       hierarchy: hierarchy,
       active: hierarchy,
       dragging: nil,
       selected: nil,
       has_unsaved_changes: false,
       modal: nil,
       breadcrumbs: breadcrumbs,
       redirect_after_save: redirect_after_save,
       available_publications: available_publications
     )}
  end

  # handle change of selection
  def handle_event("select", %{"uuid" => uuid}, socket) do
    %{active: active} = socket.assigns

    selected =
      Enum.find(active.children, fn node ->
        node.uuid == uuid
      end)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("set_active", %{"uuid" => uuid}, socket) do
    %{hierarchy: hierarchy} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

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
  def handle_event("dragstart", drag_uuid, socket) do
    {:noreply, assign(socket, dragging: drag_uuid)}
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
    %{
      section: section,
      hierarchy: hierarchy,
      pinned_project_publications: pinned_project_publications,
      redirect_after_save: redirect_after_save
    } = socket.assigns

    Sections.rebuild_section_curriculum(section, hierarchy, pinned_project_publications)
    Oli.Delivery.PreviousNextIndex.rebuild(section)

    {:noreply, redirect(socket, to: redirect_after_save)}
  end

  def handle_event("show_move_modal", %{"uuid" => uuid}, socket) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    assigns = %{
      id: "move_#{uuid}",
      node: node,
      hierarchy: hierarchy,
      from_container: active,
      active: active
    }

    {:noreply,
     assign(socket,
       modal: %{component: MoveModal, assigns: assigns}
     )}
  end

  def handle_event("show_add_materials_modal", _, socket) do
    %{
      hierarchy: hierarchy,
      available_publications: available_publications,
      pinned_project_publications: pinned_project_publications
    } = socket.assigns

    # identify preselected materials that already exist in this section
    preselected =
      Hierarchy.flatten_hierarchy(hierarchy)
      |> Enum.map(fn %{project_id: project_id, resource_id: resource_id} = _node ->
        pub = pinned_project_publications[project_id]
        {pub.id, resource_id}
      end)

    assigns = %{
      id: "add_materials_modal",
      hierarchy: nil,
      active: nil,
      selection: [],
      preselected: preselected,
      publications: available_publications,
      selected_publication: nil
    }

    {:noreply,
     assign(socket,
       modal: %{component: AddMaterialsModal, assigns: assigns}
     )}
  end

  def handle_event("AddMaterialsModal.cancel", _, socket) do
    {:noreply, socket}
  end

  def handle_event("AddMaterialsModal.add", _, socket) do
    %{
      hierarchy: hierarchy,
      active: active,
      pinned_project_publications: pinned_project_publications,
      available_publications: available_publications,
      modal: %{assigns: %{selection: selection}}
    } = socket.assigns

    publication_ids =
      selection
      |> Enum.reduce(%{}, fn {pub_id, _resource_id}, acc ->
        Map.put(acc, pub_id, true)
      end)
      |> Map.keys()

    published_resources_by_resource_id_by_pub =
      Publishing.get_published_resources_for_publications(publication_ids)

    hierarchy =
      Hierarchy.add_materials_to_hierarchy(
        hierarchy,
        active,
        selection,
        published_resources_by_resource_id_by_pub
      )

    # update pinned project publications
    pinned_project_publications =
      selection
      |> Enum.reduce(pinned_project_publications, fn {pub_id, _resource_id}, acc ->
        pub = Enum.find(available_publications, fn p -> p.id == pub_id end)
        Map.put_new(acc, pub.project_id, pub)
      end)

    # reload the updated active node
    updated = Hierarchy.find_in_hierarchy(hierarchy, active.uuid)

    {:noreply,
     socket
     |> assign(
       hierarchy: hierarchy,
       active: updated,
       pinned_project_publications: pinned_project_publications,
       has_unsaved_changes: true
     )
     |> hide_modal()}
  end

  def handle_event("HierarchyPicker.select_publication", %{"id" => publication_id}, socket) do
    %{modal: modal} = socket.assigns

    publication =
      Publishing.get_publication!(publication_id)
      |> Repo.preload([:project])

    hierarchy = publication_hierarchy(publication)

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | hierarchy: hierarchy,
            active: hierarchy,
            selected_publication: publication
        }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("HierarchyPicker.clear_publication", _, socket) do
    %{modal: modal} = socket.assigns

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | hierarchy: nil,
            active: nil
        }
    }

    {:noreply, assign(socket, modal: modal)}
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

  def handle_event(
        "HierarchyPicker.select",
        %{"uuid" => uuid},
        socket
      ) do
    %{
      modal:
        %{
          assigns: %{
            selection: selection,
            hierarchy: hierarchy,
            selected_publication: publication
          }
        } = modal
    } = socket.assigns

    item = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | selection:
              xor(
                selection,
                {publication.id, item.revision.resource_id}
              )
        }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "MoveModal.move_item",
        %{"uuid" => uuid, "to_uuid" => to_uuid},
        socket
      ) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, uuid)
    hierarchy = Hierarchy.move_node(hierarchy, node, to_uuid)

    # refresh active node
    active = Hierarchy.find_in_hierarchy(hierarchy, active.uuid)

    {:noreply,
     socket
     |> assign(hierarchy: hierarchy, active: active, has_unsaved_changes: true)
     |> hide_modal()}
  end

  def handle_event("MoveModal.cancel", _, socket) do
    {:noreply, socket}
  end

  def handle_event("show_remove_modal", %{"uuid" => uuid}, socket) do
    %{hierarchy: hierarchy} = socket.assigns

    node = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    assigns = %{
      id: "remove_#{uuid}",
      node: node
    }

    {:noreply,
     assign(socket,
       modal: %{component: RemoveModal, assigns: assigns}
     )}
  end

  def handle_event("RemoveModal.remove", %{"uuid" => uuid}, socket) do
    %{hierarchy: hierarchy, active: active} = socket.assigns

    hierarchy = Hierarchy.find_and_remove_node(hierarchy, uuid)

    # refresh active node
    active = Hierarchy.find_in_hierarchy(hierarchy, active.uuid)

    {:noreply,
     socket
     |> assign(hierarchy: hierarchy, active: active, has_unsaved_changes: true)
     |> hide_modal()}
  end

  def handle_event("RemoveModal.cancel", _, socket) do
    {:noreply, socket}
  end

  defp xor(list, item) do
    if item in list do
      Enum.filter(list, fn i -> i != item end)
    else
      [item | list]
    end
  end

  defp publication_hierarchy(publication) do
    published_resources_by_resource_id = Sections.published_resources_map(publication.id)

    %PublishedResource{revision: root_revision} =
      published_resources_by_resource_id[publication.root_resource_id]

    Hierarchy.create_hierarchy(root_revision, published_resources_by_resource_id)
  end

  ## used by add container button, disabled for now
  # defp new_container_name(%HierarchyNode{numbering: numbering} = _active) do
  #   Numbering.container_type(numbering.level + 1)
  # end

  defp render_breadcrumb(assigns) do
    %{hierarchy: hierarchy, active: active} = assigns
    breadcrumbs = Breadcrumb.breadcrumb_trail_to(hierarchy, active)

    ~L"""
      <div class="breadcrumb custom-breadcrumb p-1 px-2">
        <button id="curriculum-back" class="btn btn-sm btn-link" phx-click="set_active" phx-value-uuid="<%= previous_uuid(breadcrumbs) %>"><i class="las la-arrow-left"></i></button>

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
    <button class="breadcrumb-item btn btn-xs btn-link pl-0 pr-8" <%= if is_last, do: "disabled" %> phx-click="set_active" phx-value-uuid="<%= breadcrumb.slug %>">
      <%= get_title(breadcrumb, show_short) %>
    </button>
    """
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  defp previous_uuid(breadcrumbs) do
    previous = Enum.at(breadcrumbs, length(breadcrumbs) - 2)
    previous.slug
  end
end
