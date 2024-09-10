defmodule OliWeb.Workspaces.CourseAuthor.Objectives.DeleteModal do
  use OliWeb, :html

  alias OliWeb.Workspaces.CourseAuthor.Objectives.Attachments

  attr(:attachment_summary, :any, required: true)
  attr(:id, :string, required: true)
  attr(:project, :any, required: true)
  attr(:slug, :string, required: true)

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
            <h5 class="modal-title">Delete Objective</h5>
            <button type="button" class="btn-close" phx-click="hide_modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <.live_component
              module={Attachments}
              attachment_summary={@attachment_summary}
              project={@project}
              id="attachments"
            />
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-link" phx-click="hide_modal">Cancel</button>
            <button phx-click="delete" phx-value-slug={@slug} phx-key="enter" class="btn btn-danger">
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
