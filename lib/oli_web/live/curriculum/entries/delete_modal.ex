defmodule OliWeb.Curriculum.DeleteModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={"delete_#{@revision.slug}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Delete {resource_type_label(@revision) |> String.capitalize()}
            </h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            Are you sure you want to delete "{@revision.title}"?
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button
              phx-click="DeleteModal.delete"
              phx-key="enter"
              phx-value-slug={@revision.slug}
              class="btn btn-danger"
            >
              Delete {resource_type_label(@revision) |> String.capitalize()}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
