defmodule OliWeb.Common.DeleteModalNoConfirmation do
  use Surface.Component

  prop id, :string, required: true
  prop description, :string, required: true
  prop entity_type, :string, required: true
  prop entity_id, :string, required: true
  prop delete_enabled, :boolean, required: true
  prop delete, :event, required: true
  prop modal_action, :string, required: true

  def render(assigns) do
    ~F"""
    <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="delete-modal" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Are you absolutely sure?</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <div class="container form-container">
              <div class="mb-3">{@description}</div>
              <div class="d-flex">
                <button class="btn btn-outline-danger mt-2 flex-fill" type="submit" :on-click={@delete} disabled={!@delete_enabled} phx-value-id={@entity_id}>
                  {@modal_action} this {@entity_type}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
