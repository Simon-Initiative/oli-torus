defmodule OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Gating
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.Hierarchy.SelectResourceModal
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Revision
  alias OliWeb.Common.{Breadcrumb, DeleteModalNoConfirmation}

  def render(assigns) do
    ~F"""
    <div>nothing </div>
    """
  end

  def init(socket, module, section, context, title, parent_gate_id, gating_condition_id \\ nil) do
    parent_gate =
      case parent_gate_id do
        nil -> nil
        id -> Gating.get_gating_condition!(id)
      end

    gating_condition =
      case gating_condition_id do
        nil ->
          %{
            section_id: section.id,
            parent_id: parent_gate_id,
            resource_id:
              if is_nil(parent_gate) do
                nil
              else
                parent_gate.resource_id
              end
          }

        id ->
          Gating.get_gating_condition!(id)
          |> then(fn gc ->
            %{title: resource_title} =
              DeliveryResolver.from_resource_id(section.slug, gc.resource_id)

            user =
              if is_nil(gc.user_id) do
                nil
              else
                Oli.Accounts.get_user!(gc.user_id)
              end

            gc
            |> Map.take([:id, :type, :section_id, :resource_id])
            |> Map.put(
              :resource_title,
              resource_title
            )
            |> Map.put(
              :user,
              user
            )
            |> Map.put(
              :data,
              Map.from_struct(gc.data)
            )
          end)
      end

    socket
    |> assign(
      parent_gate: parent_gate,
      context: context,
      count_exceptions: count_exceptions(parent_gate_id, gating_condition_id),
      title: title,
      section: section,
      breadcrumbs: set_breadcrumbs(section, module, title, parent_gate),
      gating_condition: gating_condition,
      modal: nil
    )
  end

  defp set_breadcrumbs(section, module, title, parent_gate) do
    OliWeb.Sections.GatingAndScheduling.set_breadcrumbs(section, parent_gate)
    |> breadcrumb(section, module, title)
  end

  defp breadcrumb(previous, _section, _module, title) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: title
        })
      ]
  end

  defp count_exceptions(_, nil), do: nil

  defp count_exceptions(nil, gating_condition_id) do
    Gating.count_exceptions(gating_condition_id)
  end

  defp count_exceptions(_, _), do: nil

  def handle_event("show-user-picker", _, socket) do
    %{section: section, context: context} = socket.assigns

    modal_assigns = %{
      id: "select_user",
      section: section,
      context: context,
      on_select: "select_user",
      on_cancel: "cancel_select_user"
    }

    {:noreply,
     assign(socket,
       modal: %{
         component: OliWeb.Common.EnrollmentBrowser.SelectUserModal,
         assigns: modal_assigns
       }
     )}
  end

  def handle_event("select_user", %{"id" => id}, socket) do
    user = Oli.Accounts.get_user!(id)

    socket =
      assign(socket,
        gating_condition:
          Map.put(socket.assigns.gating_condition, :user_id, id) |> Map.put(:user, user)
      )

    {:noreply, socket |> hide_modal()}
  end

  def handle_event("show-resource-picker", _, socket) do
    %{section: section} = socket.assigns

    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    root = hierarchy
    filter_items_fn = fn items -> Enum.filter(items, &(&1.uuid != root.uuid)) end

    modal_assigns = %{
      id: "select_resource",
      hierarchy: hierarchy,
      active: root,
      selection: nil,
      filter_items_fn: filter_items_fn,
      on_select: "select_resource",
      on_cancel: "cancel_select_resource"
    }

    {:noreply, assign(socket, modal: %{component: SelectResourceModal, assigns: modal_assigns})}
  end

  def handle_event(
        "HierarchyPicker.update_active",
        %{"uuid" => uuid},
        socket
      ) do
    %{modal: %{assigns: %{hierarchy: hierarchy} = assigns} = modal} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    {:noreply,
     assign(socket,
       modal: %{modal | component: SelectResourceModal, assigns: %{assigns | active: active}}
     )}
  end

  def handle_event(
        "HierarchyPicker.select",
        %{"uuid" => uuid},
        socket
      ) do
    %{modal: %{assigns: %{selection: selection} = assigns} = modal} = socket.assigns

    selection =
      if selection != uuid do
        uuid
      else
        nil
      end

    {:noreply,
     assign(socket,
       modal: %{
         modal
         | component: SelectResourceModal,
           assigns: %{assigns | selection: selection}
       }
     )}
  end

  def handle_event("cancel_select_resource", _, socket) do
    {:noreply, hide_modal(socket)}
  end

  def handle_event("cancel_select_user", _, socket) do
    {:noreply, hide_modal(socket)}
  end

  def handle_event(
        "select_resource",
        %{"selection" => selection},
        socket
      ) do
    %{
      gating_condition: gating_condition,
      modal: %{assigns: %{hierarchy: hierarchy}}
    } = socket.assigns

    %HierarchyNode{resource_id: resource_id, revision: %Revision{title: title}} =
      Hierarchy.find_in_hierarchy(hierarchy, selection)

    {:noreply,
     assign(socket,
       gating_condition:
         gating_condition
         |> Map.put(:resource_id, resource_id)
         |> Map.put(:resource_title, title)
     )
     |> hide_modal()}
  end

  def handle_event(
        "select-condition",
        %{"value" => value},
        socket
      ) do
    %{gating_condition: gating_condition} = socket.assigns

    {:noreply,
     assign(socket,
       gating_condition:
         gating_condition
         |> Map.put(:type, String.to_existing_atom(value))
         |> Map.put(:data, %{})
     )}
  end

  def handle_event(
        "schedule_start_date_changed",
        %{"value" => value},
        socket
      ) do
    %{gating_condition: %{data: data} = gating_condition} = socket.assigns

    data = Map.put(data, :start_datetime, Timex.parse!(value, "{ISO:Extended}"))

    {:noreply, assign(socket, gating_condition: %{gating_condition | data: data})}
  end

  def handle_event(
        "schedule_end_date_changed",
        %{"value" => value},
        socket
      ) do
    %{gating_condition: %{data: data} = gating_condition} = socket.assigns

    data = Map.put(data, :end_datetime, Timex.parse!(value, "{ISO:Extended}"))

    {:noreply, assign(socket, gating_condition: %{gating_condition | data: data})}
  end

  def handle_event(
        "create_gate",
        _,
        socket
      ) do
    socket = clear_flash(socket)

    %{gating_condition: gating_condition, section: section} = socket.assigns

    socket =
      case Gating.create_gating_condition(gating_condition) do
        {:ok, gc} ->
          {:ok, _section} = Gating.update_resource_gating_index(section)

          socket
          |> put_flash(:info, "Gating condition successfully created.")
          |> redirect(
            to:
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Sections.GatingAndScheduling,
                section.slug
              )
          )

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Gating condition couldn't be created."
          )
      end

    {:noreply, socket}
  end

  def handle_event(
        "update_gate",
        _,
        socket
      ) do
    socket = clear_flash(socket)

    %{gating_condition: attrs, section: section} = socket.assigns
    gating_condition = Gating.get_gating_condition!(attrs.id)

    socket =
      case Gating.update_gating_condition(gating_condition, attrs) do
        {:ok, _gating_condition} ->
          {:ok, _section} = Gating.update_resource_gating_index(section)

          socket
          |> put_flash(:info, "Gating condition successfully updated.")
          |> redirect(
            to:
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Sections.GatingAndScheduling,
                section.slug
              )
          )

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Gating condition couldn't be updated."
          )
      end

    {:noreply, socket}
  end

  def handle_event("show-delete-gating-condition", %{"id" => id}, socket) do
    description =
      case socket.assigns.count_exceptions do
        nil -> ""
        0 -> ""
        1 -> "Gating condition with 1 student exception"
        n -> "Gating Condition with #{n} student exceptions"
      end

    entity_type =
      case socket.assigns.parent_gate do
        nil -> "gating condition"
        _ -> "student exception"
      end

    modal = %{
      component: DeleteModalNoConfirmation,
      assigns: %{
        id: "delete_gating_condition",
        description: description,
        entity_type: entity_type,
        entity_id: id,
        delete_enabled: true,
        delete: "delete-gating-condition"
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("delete-gating-condition", %{"id" => id}, socket) do
    socket = clear_flash(socket)
    gating_condition = Gating.get_gating_condition!(String.to_integer(id))

    socket =
      case Gating.delete_gating_condition(gating_condition) do
        {:ok, _gating_condition, _} ->
          socket
          |> put_flash(:info, "Gating condition successfully deleted.")
          |> redirect(
            to:
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Sections.GatingAndScheduling,
                socket.assigns.section.slug
              )
          )

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Gating condition couldn't be deleted."
          )
      end

    {:noreply, socket |> hide_modal()}
  end
end
