defmodule OliWeb.Common.EnrollmentBrowser.SelectUserModal do
  use OliWeb, :html

  attr :section, :map, required: true
  attr :ctx, :map, required: true

  attr :on_select, :string, required: true
  attr :on_cancel, :string, default: nil

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      style="display: block"
      id={@id}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Select Student</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <.live_component
              module={OliWeb.Common.EnrollmentBrowser.EnrollmentPicker}
              id={"#{@id}_enrollment_picker"}
              section={@section}
              ctx={@ctx}
            />
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click={@on_cancel}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
