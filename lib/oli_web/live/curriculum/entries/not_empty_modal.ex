defmodule OliWeb.Curriculum.NotEmptyModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  def render(%{revision: revision} = assigns) do
    ~H"""
    <div class="modal fade show" id={"not_empty_#{revision.slug}"} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Delete <%= resource_type_label(revision) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              This resource cannot be deleted because it is not empty.  Remove all pages
              contained within this unit or module.
            </div>
            <div class="modal-footer">
              <button
                phx-click="dismiss"
                phx-key="enter"
                phx-value-slug={revision.slug}
                class="btn btn-primary">
                Ok
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
