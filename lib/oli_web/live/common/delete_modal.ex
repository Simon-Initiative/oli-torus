defmodule OliWeb.Common.DeleteModal do
  use OliWeb, :html

  attr(:id, :string, required: true)
  attr(:description, :string, required: true)
  attr(:entity_name, :string, required: true)
  attr(:entity_type, :string, required: true)
  attr(:delete_enabled, :boolean, required: true)
  attr(:validate, :any, required: true)
  attr(:delete, :any, required: true)

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
              <div>
                <p>Please type <strong>{@entity_name}</strong> below to confirm.</p>
              </div>
              <.form
                for={%{}}
                id={"delete_#{@entity_type}_form"}
                phx-submit={@delete}
                phx-change={@validate}
              >
                <div class="form-group">
                  <input type="text" name={:name} class="form-control" placeholder={@entity_name} />
                </div>
                <div class="d-flex">
                  <button
                    class="btn btn-outline-danger mt-2 flex-fill"
                    type="submit"
                    onclick={"$('##{@id}').modal('hide')"}
                    disabled={!@delete_enabled}
                  >
                    Delete this {@entity_type}
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
