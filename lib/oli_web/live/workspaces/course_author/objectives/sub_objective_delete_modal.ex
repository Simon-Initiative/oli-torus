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
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      aria-describedby={"#{@id}-description"}
      data-dismiss-event="return_to_add_existing"
      data-parent-slug={@parent_slug}
      data-focus-delete-slug={@slug}
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content !rounded-xl border-0 bg-Background-bg-secondary shadow-xl">
          <div class="modal-header border-Border-border-default">
            <h2 id={"#{@id}-title"} class="modal-title text-xl font-bold text-Text-text-high">
              Delete sub-objective?
            </h2>
            <button
              type="button"
              class="btn-close rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
              data-bs-dismiss="modal"
              aria-label="Close delete sub-objective dialog"
            >
            </button>
          </div>
          <div id={"#{@id}-description"} class="modal-body text-Text-text-high">
            <strong>“{@title}”</strong> is not associated with any learning objectives. Deleting it
            will permanently remove it from this course. This action cannot be undone.
          </div>
          <div class="modal-footer border-Border-border-default">
            <button
              type="button"
              class="rounded-md px-4 py-2 font-semibold text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
              data-bs-dismiss="modal"
            >
              Cancel
            </button>
            <button
              phx-click="delete_sub_objective"
              phx-value-slug={@slug}
              phx-key="enter"
              class="rounded-md bg-Border-border-danger px-4 py-2 font-semibold text-white hover:opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Icon-icon-danger"
            >
              Delete sub-objective
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
