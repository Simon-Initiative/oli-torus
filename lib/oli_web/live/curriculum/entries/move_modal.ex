defmodule OliWeb.Curriculum.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Curriculum.HierarchyPicker

  def render(%{revision: revision, container: container, project: project} = assigns) do
    ~L"""
    <div class="modal fade show" style="display: block" id="move_<%= revision.slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Move Item</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
            <%= live_component @socket, HierarchyPicker,
              id: "hierarchy_picker_#{revision.slug}",
              project: project,
              container: container,
              revision: revision %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel">Cancel</button>
              <button type="submit" class="btn btn-primary" onclick="$('#move_<%= revision.slug %>').modal('hide')">Move</button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
