defmodule OliWeb.Common.Modal.DeleteModal do
  @moduledoc """
  LiveView modal for confirming a deletion action
  """
  use Phoenix.Component
  use Phoenix.HTML

  attr :title, :string, required: true
  attr :message, :any, required: true
  attr :preview_fn, :any, required: true
  attr :on_delete, :string, required: true
  attr :phx_values, :map, required: true

  def modal(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{@title}</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <p>{@message}</p>
            <div class="my-2">
              <.preview {assigns} />
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-link" data-bs-dismiss="modal">Cancel</button>
            <button class="btn btn-danger" phx-key="enter" phx-click={@on_delete} {@phx_values}>
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp preview(assigns) do
    assigns.preview_fn.(assigns)
  end
end
