defmodule OliWeb.Sections.UnlinkSection do
  use Surface.Component

  prop(section, :struct, required: true)
  prop(unlink, :event, required: true)

  def render(assigns) do
    ~F"""
    <div>
      <button type="button" class="btn btn-sm btn-outline-danger" data-toggle="modal" data-target="#deleteSectionModal">Unlink Course Section from LMS</button>

      <div class="modal fade" id="deleteSectionModal" tabindex="-1" role="dialog" aria-labelledby="deleteSectionModal" aria-hidden="true">
        <div class="modal-dialog" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title" id="deleteSectionModal">Confirm Unlink Section</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              Are you sure you want to unlink this section?
              <div class="alert alert-danger my-2" role="alert">
                <b>Warning:</b> This action cannot be undone
              </div>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-link" data-bs-dismiss="modal">Cancel</button>
              <button type="button" class="btn btn-danger ml-2" :on-click={@unlink} phx-disable-with="Unlinking...">Confirm Unlink Section</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
