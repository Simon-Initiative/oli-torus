defmodule OliWeb.Resources.AlternativesEditor.PreventDeletionModal do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  attr :references, :list, required: true
  attr :project_slug, :string, required: true

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
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Cannot Delete Alternatives</h5>
          </div>
          <div class="modal-body">
            <p class="mb-4">
              This alternatives group is used by the following pages. Remove the references
              from these pages before deleting this group.
            </p>
            <ul>
              <%= for %{slug: slug, title: title} <- @references do %>
                <li>
                  <a
                    href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, slug)}
                    target="_blank"
                  >
                    {title} <i class="fas fa-external-link-alt"></i>
                  </a>
                </li>
              <% end %>
            </ul>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-primary" data-bs-dismiss="modal">Ok</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
