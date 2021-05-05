defmodule OliWeb.Curriculum.DetailsModal do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  import OliWeb.Curriculum.Utils

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal" id="details_<%= @revision.slug %>" tabindex="-1" role="dialog" aria-labelledby="detailsModalLabel" aria-hidden="true" phx-update="ignore">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <%= f = form_for @changeset, "#",
            id: "revision-settings-form",
            phx_target: @myself,
            phx_change: "validate",
            phx_submit: "save" %>

            <div class="modal-header">
              <h5 class="modal-title text-truncate" id="detailsModalLabel"><%= resource_type_label(@revision) |> String.capitalize() %> Details</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <div class="form-group">
                <%= label f, "Title" %>
                <%= text_input f, :title, class: "form-control", aria_describedby: "title", placeholder: "Title" %>
                <small id="title" class="form-text text-muted">The title used to identify this <%= resource_type_label(@revision) %>.</small>
              </div>

              <%= if !is_container?(@revision) do %>
                <div class="form-group">
                  <%= label f, "Grading Type" %>
                  <%= select f, :graded, ["Graded Assessment": "true", "Ungraded Practice Page": "false"], class: "custom-select", class: "form-control", aria_describedby: "gradingType", placeholder: "Grading Type" %>
                  <small id="gradingType" class="form-text text-muted">Graded assessments report a grade to the grade book, while practice pages do not.</small>
                </div>

                <div class="form-group">
                  <%= label f, "Number of Attempts" %>
                  <%= select f, :max_attempts, 1..10, class: "custom-select", disabled: is_disabled(@changeset, @revision), class: "form-control", aria_describedby: "numberOfAttempts", placeholder: "Number of Attempts" %>
                  <small id="numberOfAttempts" class="form-text text-muted">Graded assessments allow a configurable number of attempts, while practice pages offer unlimited attempts.</small>
                </div>

                <div class="form-group">
                  <%= label f, "Scoring Strategy" %>
                  <%= select f, :scoring_strategy_id,
                      Enum.map(ScoringStrategy.get_types(),
                              & {Oli.Utils.snake_case_to_friendly(&1[:type]), &1[:id]}),
                      class: "custom-select",
                      disabled: is_disabled(@changeset, @revision),
                      class: "form-control",
                      aria_describedby: "scoringStrategy",
                      placeholder: "Scoring Strategy" %>
                  <small id="scoringStrategy" class="form-text text-muted">The scoring strategy determines how to calculate the final grade book score across all attempts.</small>
                </div>
              <% end %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <%= submit "Save", phx_disable_with: "Saving...", class: "btn btn-primary" %>
            </div>

          </form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{revision: revision} = assigns, socket) do
    changeset = Resources.change_revision(revision)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"revision" => revision_params}, socket) do
    changeset =
      socket.assigns.revision
      |> Resources.change_revision(revision_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"revision" => revision_params}, socket) do
    save_revision(socket, revision_params)
  end

  defp save_revision(socket, revision_params) do
    case ContainerEditor.edit_page(
           socket.assigns.project,
           socket.assigns.revision.slug,
           revision_params
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Details saved for #{resource_type_label(socket.assigns.revision)} \"#{revision_params["title"]}\"")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp is_disabled(changeset, revision) do
    if !is_nil(changeset.changes[:graded]) do
      !changeset.changes[:graded]
    else
      !revision.graded
    end
  end
end
