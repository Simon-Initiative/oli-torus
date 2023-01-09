defmodule OliWeb.Curriculum.OptionsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.ExplanationStrategy

  def render(assigns) do
    assigns =
      assigns
      |> assign(:attempt_options,
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
      )

    ~H"""
    <div class="modal fade show" style="display: block" id={"options_#{@revision.slug}"} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <%= form_for @changeset, "#",
            [id: "revision-settings-form",
            phx_change: "validate-options",
            phx_submit: "save-options"],
            fn f -> %>

              <div class="modal-header">
                <h5 class="modal-title text-truncate"><%= resource_type_label(@revision) |> String.capitalize() %> Options</h5>
                <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div class="modal-body">
                <div class="form-group">
                  <%= label f, "Title" %>
                  <%= text_input f, :title, class: "form-control", aria_describedby: "title", placeholder: "Title" %>
                  <small id="title" class="form-text text-muted">The title is used to identify this <%= resource_type_label(@revision) %>.</small>
                </div>

                <%= if !is_container?(@revision) do %>
                  <div class="form-group">
                    <%= label f, "Grading Type" %>
                    <%= select f, :graded, ["Graded Assessment": "true", "Ungraded Practice Page": "false"], class: "custom-select", class: "form-control", aria_describedby: "gradingType", placeholder: "Grading Type" %>
                    <small id="gradingType" class="form-text text-muted">Graded assessments report a grade to the grade book, while practice pages do not.</small>
                  </div>

                  <div class="form-group">
                    <%= label f, "Explanation Strategy" %>
                    <%= inputs_for f, :explanation_strategy, fn es -> %>
                      <div class="d-flex d-flex-row">
                        <%= select es, :type,
                            Enum.map(ExplanationStrategy.types(), & {Oli.Utils.snake_case_to_friendly(&1), &1}),
                            class: "custom-select form-control",
                            aria_describedby: "explanationStrategy",
                            placeholder: "Explanation Strategy" %>

                        <%= case fetch_field(es.source, :type) do %>
                          <% :after_set_num_attempts -> %>
                            <div class="ml-2">
                              <%= number_input es, :set_num_attempts, class: "form-control", aria_describedby: "numberOfAttempts", placeholder: "# of Attempts" %>
                            </div>

                          <% _ -> %>

                        <% end %>
                      </div>
                      <small id="scoringStrategy" class="form-text text-muted">Explanation strategy determines how activity explanations will be shown to learners.</small>
                    <% end %>
                  </div>

                  <div class="form-group">
                    <%= label f, "Number of Attempts" %>
                    <%= select f, :max_attempts, @attempt_options, class: "custom-select", disabled: is_disabled(@changeset, @revision), class: "form-control", aria_describedby: "numberOfAttempts", placeholder: "Number of Attempts" %>
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

                  <div class="form-group">
                    <%= label f, "Retake Mode" %>
                    <%= select f, :retake_mode, [{"Normal: Students answer all questions in each attempt", :normal}, {"Targeted: Students answer only incorrect questions from previous attempts", :targeted}],
                        class: "custom-select",
                        disabled: is_disabled(@changeset, @revision) or !@revision.graded,
                        class: "form-control",
                        aria_describedby: "retakeMode",
                        placeholder: "Retake Mode" %>
                    <small id="retakeMode" class="form-text text-muted">The retake mode determines how subsequent attempts are presented to students.</small>
                  </div>
                <% end %>
              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <%= submit "Save", phx_disable_with: "Saving...", class: "btn btn-primary" %>
              </div>
            <% end %>
        </div>
      </div>
    </div>
    """
  end

  def fetch_field(f, field) do
    case Ecto.Changeset.fetch_field(f, field) do
      {_, value} -> value
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
