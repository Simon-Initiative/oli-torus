defmodule OliWeb.ObjectivesLive.DeleteModal do
  use Surface.Component

  alias OliWeb.ObjectivesLive.Attachments

  prop id, :string, required: true
  prop slug, :string, required: true
  prop project, :any, required: true
  prop attachment_summary, :any, required: true

  def render(assigns) do
    ~F"""
      <div class="modal fade show" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog" role="document">
          <div class="modal-content">
              <div class="modal-header">
                <h5 class="modal-title">Delete Objective</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
              </div>
              <div class="modal-body">
                <Attachments
                  attachment_summary={@attachment_summary}
                  project={@project}
                  id="attachments" />
              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button
                  phx-click="delete"
                  phx-value-slug={@slug}
                  phx-key="enter"
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
