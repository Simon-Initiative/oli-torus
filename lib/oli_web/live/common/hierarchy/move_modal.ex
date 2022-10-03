defmodule OliWeb.Common.Hierarchy.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Common.Hierarchy.HierarchyPicker
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(
        %{
          id: id,
          node: %HierarchyNode{uuid: uuid, revision: revision} = node,
          hierarchy: %HierarchyNode{} = hierarchy,
          from_container: from_container,
          active: %HierarchyNode{} = active
        } = assigns
      ) do
    ~L"""
    <div class="modal fade show" style="display: block" id="<%= id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Move <%= resource_type_label(revision) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <%= live_component HierarchyPicker,
                id: "#{id}_hierarchy_picker",
                hierarchy: hierarchy,
                active: active,
                select_mode: :container,
                filter_items_fn: fn items -> Enum.filter(items, &(&1.uuid != uuid)) end %>

              <div class="text-center text-secondary mt-2">
                <%= if already_exists_in_container?(from_container, active) do %>
                <b><%= revision.title %></b> already exists here
                <% else %>
                <b><%= revision.title %></b> will be placed here
                <% end %>
              </div>

            </div>
            <div class="modal-footer">
              <%= if can_remove_page?(revision, from_container) do %>
                <button type="button"
                  id="remove_btn"
                  class="btn btn-danger"
                  title="Remove this page from the curriculum. Pages that are removed are still be accessible from All Pages view."
                  phx-click="MoveModal.remove"
                  phx-value-uuid="<%= node.uuid %>"
                  phx-value-from_uuid="<%= from_container_uuid(from_container) %>"
                  phx-hook="TooltipInit">
                  Remove
                </button>
                <div class="flex-grow-1"></div>
              <% end %>
              <button type="button" class="btn btn-secondary" phx-click="MoveModal.cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                phx-click="MoveModal.move_item"
                phx-value-uuid="<%= node.uuid %>"
                phx-value-from_uuid="<%= from_container_uuid(from_container) %>"
                phx-value-to_uuid="<%= active.uuid %>"
                <%= if can_move?(from_container, active) , do: "", else: "disabled" %>>
                Move
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp from_container_uuid(from_container) do
    case from_container do
      nil -> nil
      from_container -> from_container.uuid
    end
  end

  defp can_remove_page?(revision, from_container),
    do:
      revision.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") &&
        from_container != nil

  defp can_move?(nil, _active), do: true

  defp can_move?(from_container, active) do
    active.uuid != nil && !already_exists_in_container?(from_container, active)
  end

  defp already_exists_in_container?(from_container, active) do
    from_container != nil && active.uuid == from_container.uuid
  end
end
