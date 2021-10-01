defmodule OliWeb.Common.Hierarchy.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Common.Hierarchy.HierarchyPicker
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(
        %{
          id: id,
          node: %HierarchyNode{slug: slug, revision: revision} = node,
          hierarchy: %HierarchyNode{} = hierarchy,
          from_container: %HierarchyNode{} = from_container,
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
                filter_items_fn: fn items -> Enum.filter(items, &(&1.slug != slug)) end %>

              <div class="text-center text-secondary mt-2">
                <b><%= revision.title %></b> will be placed here
              </div>

            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="MoveModal.cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                onclick="$('#move_<%= slug %>').modal('hide')"
                phx-click="MoveModal.move_item"
                phx-value-item_slug="<%= node.slug %>"
                phx-value-from_slug="<%= from_container.slug %>"
                phx-value-to_slug="<%= active.slug %>"
                <%= if can_move?(from_container, active) , do: "", else: "disabled" %>>
                Move
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_move?(from_container, active) do
    active.slug != nil && active.slug != from_container.slug
  end
end
