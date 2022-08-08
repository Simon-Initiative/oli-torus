defmodule OliWeb.Curriculum.OptionsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources

  def update(%{revision: revision} = assigns, socket) do
    changeset = Resources.change_revision(revision)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def render(%{changeset: changeset, revision: revision} = assigns) do
    attempt_options = [
      "1": 1,
      "2": 2,
      "3": 3,
      "4": 4,
      "5": 5,
      "6": 6,
      "7": 7,
      "8": 8,
      "9": 9,
      "10": 10,
      "15": 15,
      "25": 25,
      "50": 50,
      "100": 100,
      Unlimited: 0
    ]

    ~L"""
    <div class="modal fade show" style="display: block" id="options_<%= revision.slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <%= f = form_for @changeset, "#",
            id: "revision-settings-form",
            phx_target: @myself,
            phx_change: "validate",
            phx_submit: "save" %>

              <div class="modal-header">
                <h5 class="modal-title text-truncate"><%= resource_type_label(revision) |> String.capitalize() %> Options</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div class="modal-body">
                <div class="form-group">
                  <%= label f, "Title" %>
                  <%= text_input f, :title, class: "form-control", aria_describedby: "title", placeholder: "Title" %>
                  <small id="title" class="form-text text-muted">The title is used to identify this <%= resource_type_label(revision) %>.</small>
                </div>

                <%= if !is_container?(@revision) do %>
                  <div class="form-group">
                    <%= label f, "Grading Type" %>
                    <%= select f, :graded, ["Graded Assessment": "true", "Ungraded Practice Page": "false"], class: "custom-select", class: "form-control", aria_describedby: "gradingType", placeholder: "Grading Type" %>
                    <small id="gradingType" class="form-text text-muted">Graded assessments report a grade to the grade book, while practice pages do not.</small>
                  </div>

                  <div class="form-group">
                    <%= label f, "Number of Attempts" %>
                    <%= select f, :max_attempts, attempt_options, class: "custom-select", disabled: is_disabled(changeset, revision), class: "form-control", aria_describedby: "numberOfAttempts", placeholder: "Number of Attempts" %>
                    <small id="numberOfAttempts" class="form-text text-muted">Graded assessments allow a configurable number of attempts, while practice pages offer unlimited attempts.</small>
                  </div>

                  <div class="form-group">
                    <%= label f, "Scoring Strategy" %>
                    <%= select f, :scoring_strategy_id,
                        Enum.map(ScoringStrategy.get_types(),
                                & {Oli.Utils.snake_case_to_friendly(&1[:type]), &1[:id]}),
                        class: "custom-select",
                        disabled: is_disabled(changeset, revision),
                        class: "form-control",
                        aria_describedby: "scoringStrategy",
                        placeholder: "Scoring Strategy" %>
                    <small id="scoringStrategy" class="form-text text-muted">The scoring strategy determines how to calculate the final grade book score across all attempts.</small>
                  </div>

                  <div class="form-group">
                    <%= label f, "Retake Mode" %>
                    <%= select f, :retake_mode, [{"Normal: Students answer all questions in each attempt", :normal}, {"Targeted: Students answer only incorrect questions from previous attempts", :targeted}],
                        class: "custom-select",
                        disabled: is_disabled(changeset, revision) or !@revision.graded,
                        class: "form-control",
                        aria_describedby: "retakeMode",
                        placeholder: "Retake Mode" %>
                    <small id="retakeMode" class="form-text text-muted">The retake mode determines how subsequent attempts are presented to students.</small>
                  </div>
                <% end %>
              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <%= submit "Save", phx_disable_with: "Saving...", class: "btn btn-primary", onclick: "$('#options_#{revision.slug}').modal('hide')" %>
              </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"revision" => revision_params}, socket) do
    changeset =
      socket.assigns.revision
      |> Resources.change_revision(revision_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"revision" => revision_params}, socket) do
    save_revision(socket, revision_params)
  end

  defp save_revision(socket, revision_params) do
    %{container: container, project: project, revision: revision} = socket.assigns

    case ContainerEditor.edit_page(project, revision.slug, revision_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{resource_type_label(revision) |> String.capitalize()} options saved"
         )
         |> push_redirect(to: Routes.container_path(socket, :index, project.slug, container.slug))}

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
