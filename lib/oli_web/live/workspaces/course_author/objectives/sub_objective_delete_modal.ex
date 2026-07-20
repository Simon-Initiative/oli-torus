defmodule OliWeb.Workspaces.CourseAuthor.Objectives.SubObjectiveDeleteModal do
  use OliWeb, :html

  attr(:id, :string, required: true)
  attr(:parent_slug, :string, required: true)
  attr(:slug, :string, required: true)
  attr(:title, :string, required: true)

  def render(assigns) do
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
            <h5 class="modal-title">Delete Sub-Objective</h5>
            <button type="button" class="btn-close" phx-click="hide_modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            Are you sure you want to delete <strong>{@title}</strong>?
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-link" phx-click="hide_modal">Cancel</button>
            <button
              phx-click="delete_sub_objective"
              phx-value-slug={@slug}
              phx-value-parent_slug={@parent_slug}
              phx-key="enter"
              class="btn btn-danger"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
