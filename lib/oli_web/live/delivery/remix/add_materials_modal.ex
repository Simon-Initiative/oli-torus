defmodule OliWeb.Delivery.Remix.AddMaterialsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Common.Hierarchy.HierarchyPicker

  def render(
        %{
          id: id,
          hierarchy: hierarchy,
          active: active,
          selection: selection,
          preselected: preselected,
          publications: publications,
          selected_publication: selected_publication
        } = assigns
      ) do
    ~L"""
    <div class="modal fade show" style="display: block" id="<%= id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Add Materials</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
            <%= live_component HierarchyPicker,
              id: "hierarchy_picker",
              select_mode: :multiple,
              hierarchy: hierarchy,
              active: active,
              selection: selection,
              preselected: preselected,
              publications: publications,
              selected_publication: selected_publication %>
            </div>
            <div class="modal-footer">
              <%= if Enum.count(selection) > 0 do %>
                <span class="mr-2">
                  <%= Enum.count(selection) %> items selected
                </span>
              <% end %>
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="AddMaterialsModal.cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                onclick="$('#<%= id %>').modal('hide')"
                phx-click="AddMaterialsModal.add"
                <%= if can_add?(selection) , do: "", else: "disabled" %>>
                Add
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_add?(selection) do
    !Enum.empty?(selection)
  end
end
