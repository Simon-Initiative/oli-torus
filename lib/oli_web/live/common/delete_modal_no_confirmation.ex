defmodule OliWeb.Common.DeleteModalNoConfirmation do
  use OliWeb, :html

  attr(:id, :string, required: true)
  attr(:description, :string, required: true)
  attr(:entity_type, :string, required: true)
  attr(:entity_id, :string, required: true)
  attr(:delete_enabled, :boolean, required: true)
  attr(:delete, :any, required: true)
  attr(:modal_action, :string, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      style="display: block"
      tabindex="-1"
      role="dialog"
      aria-labelledby="delete-modal"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Are you absolutely sure?</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <div class="container form-container">
              <div class="mb-3">{@description}</div>
              <div class="d-flex">
                <button
                  class="btn btn-outline-danger mt-2 flex-fill"
                  type="submit"
                  phx-click={@delete}
                  disabled={!@delete_enabled}
                  phx-value-id={@entity_id}
                >
                  {"#{@modal_action} this #{@entity_type}"}
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
