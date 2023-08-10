defmodule OliWeb.Curriculum.OptionsModal do
  use OliWeb, :html

  import OliWeb.Curriculum.Utils

  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.ExplanationStrategy
  alias OliWeb.Components.HierarchySelector

  @attempt_options [
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

  attr(:redirect_url, :string, required: true)
  attr(:revision, :map, required: true)
  attr(:changeset, :map, required: true)
  attr(:project, :map, required: true)
  attr(:project_hierarchy, :map, required: true)
  attr(:validate, :string, required: true)
  attr(:submit, :string, required: true)

  attr(:attempt_options, :list, default: @attempt_options)
  attr(:selected_resources, :list, default: [])

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      style="display: block"
      id={"options_#{@revision.slug}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <.form
            for={@changeset}
            id="revision-settings-form"
            phx-change={@validate}
            phx-submit={@submit}
          >
            <div class="modal-header">
              <h5 class="modal-title text-truncate">
                <%= resource_type_label(@revision) |> String.capitalize() %> Options
              </h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close" />
            </div>
            <div class="modal-body">
              <div class="form-group">
                <label for="title">Title</label>
                <.input
                  id="title"
                  name="revision[title]"
                  class="form-control"
                  aria-describedby="title_description"
                  placeholder="Title"
                  value={fetch_field(@changeset, :title)}
                />
                <small id="title_description" class="form-text text-muted">
                  The title is used to identify this <%= resource_type_label(@revision) %>.
                </small>
              </div>

              <%= if !is_container?(@revision) do %>
                <div class="form-group">
                  <label for="grading_type">Grading Type</label>
                  <.input
                    type="select"
                    name="revision[graded]"
                    id="grading_type"
                    aria-describedby="grading_type_description"
                    placeholder="Grading Type"
                    class="form-control custom-select"
                    value={fetch_field(@changeset, :graded)}
                    options={[{"Graded Assessment", "true"}, {"Ungraded Practice Page", "false"}]}
                  />
                  <small id="grading_type_description" class="form-text text-muted">
                    Graded assessments report a grade to the grade book, while practice pages do not.
                  </small>
                </div>

                <div class="form-group">
                  <label>Explanation Strategy</label>
                  <div class="flex gap-2">
                    <.input
                      type="select"
                      name="revision[explanation_strategy][type]"
                      class="form-control custom-select w-full"
                      aria-describedby="explanation_strategy_description"
                      placeholder="Explanation Strategy"
                      value={Map.get(fetch_field(@changeset, :explanation_strategy) || %{}, :type)}
                      options={
                        Enum.map(
                          ExplanationStrategy.types(),
                          &{Oli.Utils.snake_case_to_friendly(&1), &1}
                        )
                      }
                    />
                    <%= case Map.get(fetch_field(@changeset, :explanation_strategy) || %{}, :type) do %>
                      <% :after_set_num_attempts -> %>
                        <div class="ml-2">
                          <.input
                            name="revision[explanation_strategy][set_num_attempts]"
                            type="number"
                            class="form-control"
                            placeholder="# of Attempts"
                            value={
                              Map.get(
                                fetch_field(@changeset, :explanation_strategy),
                                :set_num_attempts
                              )
                            }
                          />
                        </div>
                      <% _ -> %>
                    <% end %>
                  </div>
                  <small id="explanation_strategy_description" class="form-text text-muted">
                    Explanation strategy determines how activity explanations will be shown to learners.
                  </small>
                </div>

                <div class="form-group">
                  <label for="max_attempts">Number of Attempts</label>
                  <.input
                    type="select"
                    id="max_attempts"
                    name="revision[max_attempts]"
                    aria-describedby="number_of_attempts_description"
                    placeholder="Number of Attempts"
                    disabled={is_disabled(@changeset, @revision)}
                    class="form-control custom-select"
                    value={fetch_field(@changeset, :max_attempts) || 0}
                    options={@attempt_options}
                  />
                  <small id="number_of_attempts_description" class="form-text text-muted">
                    Graded assessments allow a configurable number of attempts, while practice pages offer unlimited attempts.
                  </small>
                </div>

                <div class="form-group">
                  <label for="scoring_strategy_id">Scoring Strategy</label>
                  <.input
                    type="select"
                    id="scoring_strategy_id"
                    name="revision[scoring_strategy_id]"
                    aria-describedby="scoring_strategy_description"
                    placeholder="Scoring Strategy"
                    disabled={is_disabled(@changeset, @revision)}
                    class="form-control custom-select"
                    value={fetch_field(@changeset, :scoring_strategy_id)}
                    options={
                      Enum.map(
                        ScoringStrategy.get_types(),
                        &{Oli.Utils.snake_case_to_friendly(&1[:type]), &1[:id]}
                      )
                    }
                  />
                  <small id="scoring_strategy_description" class="form-text text-muted">
                    The scoring strategy determines how to calculate the final grade book score across all attempts.
                  </small>
                </div>

                <div class="form-group">
                  <label for="retake_mode">Retake Mode</label>
                  <.input
                    type="select"
                    id="retake_mode"
                    name="revision[retake_mode]"
                    aria-describedby="retake_mode_description"
                    placeholder="Retake Mode"
                    disabled={is_disabled(@changeset, @revision)}
                    class="form-control custom-select"
                    value={fetch_field(@changeset, :retake_mode)}
                    options={[
                      {"Normal: Students answer all questions in each attempt", :normal},
                      {"Targeted: Students answer only incorrect questions from previous attempts",
                       :targeted}
                    ]}
                  />
                  <small id="retake_mode_description" class="form-text text-muted">
                    The retake mode determines how subsequent attempts are presented to students.
                  </small>
                </div>

                <div class="form-group">
                  <label for="purpose">Purpose</label>
                  <.input
                    type="select"
                    id="purpose"
                    name="revision[purpose]"
                    placeholder="Purpose"
                    class="form-control custom-select"
                    value={fetch_field(@changeset, :purpose)}
                    options={[{"Foundation", :foundation}, {"Exploration", :application}]}
                  />
                </div>

                <div class="form-group">
                  <label>Related Resource</label>
                  <%= live_component(HierarchySelector,
                    disabled: !@revision.graded && is_foundation(@changeset, @revision),
                    field_name: "revision[relates_to][]",
                    id: "related-resources-selector",
                    items: @project_hierarchy.children,
                    initial_values: get_selected_related_resources(@revision, @project_hierarchy)
                  ) %>
                </div>
              <% end %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
              <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">Save</button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp is_foundation(changeset, revision) do
    if !is_nil(changeset.changes |> Map.get(:purpose)) do
      changeset.changes.purpose == :foundation
    else
      revision.purpose == :foundation
    end
  end

  defp is_disabled(changeset, revision) do
    if !is_nil(changeset.changes[:graded]) do
      !changeset.changes[:graded]
    else
      !revision.graded
    end
  end

  defp get_selected_related_resources(revision, project_hierarchy) do
    related_resources = revision.relates_to
    flatten_project_hierarchy = flatten_project_hierarchy(project_hierarchy)

    Enum.reduce(flatten_project_hierarchy, [], fn {name, id}, acc ->
      if Enum.member?(related_resources, id) do
        [{name, "#{id}"}] ++ acc
      else
        acc
      end
    end)
  end

  defp flatten_project_hierarchy(%{id: id, name: name, children: children}) do
    children
    |> Enum.map(&flatten_project_hierarchy/1)
    |> List.flatten()
    |> Enum.concat([{name, id}])
  end
end
