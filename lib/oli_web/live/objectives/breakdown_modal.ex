defmodule OliWeb.Objectives.BreakdownModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import OliWeb.ErrorHelpers

  alias OliWeb.Router.Helpers, as: Routes

  def render(%{slug: slug} = assigns) do

    ~L"""

    <div class="modal fade show" id="breakdown_<%= slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <%= f = form_for @changeset, "#", [phx_submit: "perform_breakdown", id: "process-breakdown-" <> slug] %>
            <div class="modal-header">
              <h5 class="modal-title">Break down objective</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <p class="mb-4">
              This operation will break down this objective into smaller sub-objectives.
              All activities that are currently linked to this objective will remain linked to the resulting sub-objective.
              </p>
              <p class="text-center">
                <img src="<%= Routes.static_path(OliWeb.Endpoint, "/images/objectives/breakdown_objective.svg") %>" />
              </p>
              <p>
              This is usually performed on objectives that have been identified as too large after analyzing student data.
              </p>

              <p>
              Please enter a title for the new parent objective:
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
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel_breakdown">Cancel</button>
              <button type="submit" class="btn btn-warning" phx-click="cancel_breakdown" onclick="$('#breakdown_<%= slug %>').modal('hide')">Continue</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

end
