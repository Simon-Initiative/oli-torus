defmodule OliWeb.Objectives.BreakdownModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import OliWeb.ErrorHelpers

  alias OliWeb.Router.Helpers, as: Routes

  def render(%{id: id, slug: slug} = assigns) do
    ~L"""
    <div class="modal fade show" id="<%= id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <%= f = form_for @changeset, "#", [phx_submit: "breakdown", id: "breakdown-" <> slug] %>
            <div class="modal-header">
              <h5 class="modal-title">Break down objective</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <p class="mb-4">
              Is this objective too broad? Convert this objective into a sub-objective under a new parent objective.
              </p>
              <p>
              All activities linked to this sub-objective will remain linked.
              </p>
              <p class="text-center">
                <img class="img-fluid" src="<%= Routes.static_path(OliWeb.Endpoint, "/images/objectives/breakdown_objective.svg") %>" />
              </p>
              <hr />
              <p>
              What would you like to call your new parent objective?
              </p>

              <p>
                <%= text_input f,
                  :title,
                  value: "",
                  class: "form-control",
                  placeholder: "e.g. Recognize the structures of amino acids, carbohydrates, lipids, and nucleic acids",
                  id: "parent-title",
                  phx_hook: "InputAutoSelect",
                  required: true %>
                <%= hidden_input f,
                  :parent_slug,
                  value: nil %>
                <%= hidden_input f,
                  :slug,
                  value: @slug %>
                <%= error_tag f, :title %>
              </p>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <button type="submit" class="btn btn-primary">Break down objective</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
