defmodule OliWeb.Objectives.SelectionsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Router.Helpers, as: Routes

  def render(%{project_slug: project_slug} = assigns) do
    ~L"""
    <div class="modal fade show" id="selection_<%= project_slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Cannot Delete Objective</h5>
          </div>
          <div class="modal-body">
            <p class="mb-4">
              This objective is in use within activity bank sections in the following pages. Remove the references
              to this objective from these pages before deleting this objective.
            </p>
            <ul>
              <%= for %{slug: slug, title: title} <- @selections do %>
                <li>
                  <a href="<%= Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, slug) %>" target="_blank"><%= title %></a>
                </li>
              <% end %>
            </ul>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Done</button>
          </div>

        </div>
      </div>
    </div>
    """
  end
end
