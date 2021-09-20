defmodule OliWeb.Delivery.Remix.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.HierarchyPicker
  alias Oli.Publishing.HierarchyNode

  def render(
        %{
          node: %HierarchyNode{slug: slug, revision: revision} = node,
          breadcrumbs: breadcrumbs,
          old_container: old_container,
          container: container,
          selection: selection
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
              container: container,
              breadcrumbs: breadcrumbs %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="MoveModal.cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                onclick="$('#move_<%= slug %>').modal('hide')"
                phx-click="MoveModal.move_item"
                phx-value-slug="<%= node.slug %>"
                phx-value-selection="<%= selection %>"
                <%= if can_move?(old_container, selection) , do: "", else: "disabled" %>>
                Move
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_move?(old_container, selected_slug) do
    selected_slug != nil && selected_slug != old_container.slug
  end
end
