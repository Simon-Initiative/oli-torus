defmodule OliWeb.Common.Hierarchy.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Common.Hierarchy.HierarchyPicker
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(
        %{
          node: %HierarchyNode{slug: slug, revision: revision} = node,
          hierarchy: %HierarchyNode{} = hierarchy,
          from_container: %HierarchyNode{} = from_container,
          selection: %HierarchyNode{} = selection
        } = assigns
      ) do
    ~L"""
    <div class="modal fade show" style="display: block" id="move_<%= slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
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
              id: "hierarchy_picker_#{slug}",
              node: node,
              hierarchy: hierarchy,
              selection: selection %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="MoveModal.cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                onclick="$('#move_<%= slug %>').modal('hide')"
                phx-click="MoveModal.move_item"
                phx-value-item_slug="<%= node.slug %>"
                phx-value-from_slug="<%= from_container.slug %>"
                phx-value-to_slug="<%= selection.slug %>"
                <%= if can_move?(from_container, selection) , do: "", else: "disabled" %>>
                Move
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_move?(from_container, selection) do
    selection.slug != nil && selection.slug != from_container.slug
  end
end
