defmodule OliWeb.Curriculum.HyperlinkDependencyModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML
  use OliWeb, :verified_routes

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={"not_empty_#{@revision.slug}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Delete "{@revision.title}"
            </h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            This resource cannot be deleted because it contains hyperlinks to other resources. Please check the following list and modify it accordingly:
            <ul class="pl-5 pt-3 max-w-md space-y-1 text-gray-500 list-disc list-inside dark:text-gray-400">
              <li :for={hyperlink <- @hyperlinks}>
                {hyperlink.title}
                <.link
                  class="entry-title mx-3"
                  href={~p"/authoring/project/#{@project.slug}/resource/#{hyperlink.slug}"}
                >
                  Edit Page
                </.link>
              </li>
            </ul>
          </div>
          <div class="modal-footer">
            <button
              phx-click="dismiss"
              phx-key="enter"
              phx-value-slug={@revision.slug}
              class="btn btn-primary"
            >
              Ok
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
