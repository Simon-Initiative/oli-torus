defmodule OliWeb.Common.EnrollmentBrowser.SelectUserModal do
  use Surface.Component

  alias OliWeb.Common.EnrollmentBrowser.EnrollmentPicker

  prop section, :struct, required: true
  prop context, :struct, required: true

  prop on_select, :event, required: true
  prop on_cancel, :event, default: nil

  def render(
        %{
          id: id
        } = assigns
      ) do
    ~F"""
    <div class="modal fade show" style="display: block" id={id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Select Student</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
            {live_component EnrollmentPicker,
                id: "#{id}_enrollment_picker",
                section: assigns.section,
                context: assigns.context}
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" :on-click={@on_cancel}>Cancel</button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
