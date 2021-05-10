defmodule OliWeb.Curriculum.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Curriculum.HierarchyPicker

  def render(%{slug: slug} = assigns) do
    ~L"""
    <div class="modal fade show" style="display: block" id="move_<%= slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Move Item</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <%= live_component @socket, HierarchyPicker, id: "move_#{slug}" %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel">Cancel</button>
              <button type="submit" class="btn btn-primary" onclick="$('#move_<%= slug %>').modal('hide')">Move</button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
