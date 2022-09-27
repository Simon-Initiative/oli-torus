defmodule OliWeb.Objectives.DeleteModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.Attachments

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="<%= @id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Delete Objective</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <%= live_component Attachments, attachment_summary: @attachment_summary, project: @project %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <button
                phx-click="delete"
                phx-key="enter"
                phx-value-slug="<%= @slug %>"
                phx-value-parent_slug="<%= @parent_slug_value %>"
                class="btn btn-warning">
                Delete
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
