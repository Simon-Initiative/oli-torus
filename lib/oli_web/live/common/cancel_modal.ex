defmodule OliWeb.Common.Cancel do
  use Phoenix.LiveComponent

  attr :title, :string, required: true
  attr :ok, :any, required: true
  attr :cancel, :any, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal fade show"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{assigns.title}</h5>
          </div>
          <div class="modal-body">
            {render_slot(@inner_block)}
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click={@cancel}
            >
              Cancel
            </button>
            <button type="button" class="btn btn-primary" data-bs-dismiss="modal" phx-click={@ok}>
              Ok
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
