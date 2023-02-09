defmodule OliWeb.Curriculum.OptionsModal do
  use Surface.LiveComponent

  import OliWeb.Curriculum.Utils

  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.ExplanationStrategy
  alias OliWeb.Components.HierarchySelector

  alias Surface.Components.Form
  alias Surface.Components.Form.{TextInput, Label, Field, Select, Inputs, NumberInput}

  prop redirect_url, :string, required: true
  prop revision, :struct, required: true
  prop changeset, :struct, required: true
  prop project, :struct, required: true
  prop project_hierarchy, :struct, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true

  data mounted, :boolean, default: false
  data attempt_options, :list, default: []
  data selected_resources, :list, default: []

  def update(assigns, socket) do
    assigns =
      if not socket.assigns.mounted do
        assigns
        |> Map.put(
          :attempt_options,
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
        |> Map.put(
          :selected_resources,
          get_selected_related_resources(assigns.revision, assigns.project_hierarchy)
        )
        |> Map.put(
          :mounted,
          true
        )
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~F"""
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
          <Form for={@changeset} id="revision-settings-form" change={@validate} submit={@submit}>
            <div class="modal-header">
              <h5 class="modal-title text-truncate">{resource_type_label(@revision) |> String.capitalize()} Options</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close" />
            </div>
            <div class="modal-body">
              <Field name={:title} class="form-group">
                <Label>Title</Label>
                <TextInput class="form-control" opts={aria_describedby: "title", placeholder: "Title"} />
                <small id="title" class="form-text text-muted">The title is used to identify this {resource_type_label(@revision)}.</small>
              </Field>

              {#if !is_container?(@revision)}
                <Field name={:graded} class="form-group">
                  <Label>Grading Type</Label>
                  <Select
                    options={"Graded Assessment": "true", "Ungraded Practice Page": "false"}
                    opts={aria_describedby: "gradingType", placeholder: "Grading Type"}
                    class="form-control custom-select"
                  />
                  <small id="gradingType" class="form-text text-muted">Graded assessments report a grade to the grade book, while practice pages do not.</small>
                </Field>

                <div class="form-group">
                  <Label>Explanation Strategy</Label>
                  <div class="flex gap-2">
                    <Inputs for={:explanation_strategy}>
                      <Field class="flex-1" name={:type}>
                        <Select
                          options={Enum.map(ExplanationStrategy.types(), &{Oli.Utils.snake_case_to_friendly(&1), &1})}
                          class="form-control custom-select"
                          opts={aria_describedby: "explanationStrategy", placeholder: "Explanation Strategy"}
                        />
                      </Field>
                      {#case Map.get(fetch_field(@changeset, :explanation_strategy) || %{}, :type)}
                        {#match :after_set_num_attempts}
                          <div class="ml-2">
                            <Field name={:set_num_attempts}>
                              <NumberInput
                                class="form-control"
                                opts={aria_describedby: "numberOfAttempts", placeholder: "# of Attempts"}
                              />
                            </Field>
                          </div>
                        {#match _}
                      {/case}
                    </Inputs>
                  </div>
                  <small id="scoringStrategy" class="form-text text-muted">Explanation strategy determines how activity explanations will be shown to learners.</small>
                </div>

                <div class="form-group">
                  <Label>Number of Attempts</Label>
                  <Field name={:max_attempts}>
                    <Select
                      options={@attempt_options}
                      opts={
                        aria_describedby: "numberOfAttempts",
                        placeholder: "Number of Attempts",
                        disabled: is_disabled(@changeset, @revision)
                      }
                      class="form-control custom-select"
                    />
                  </Field>
                  <small id="numberOfAttempts" class="form-text text-muted">Graded assessments allow a configurable number of attempts, while practice pages offer unlimited attempts.</small>
                </div>

                <div class="form-group">
                  <Label>Scoring Strategy</Label>
                  <Field name={:scoring_strategy_id}>
                    <Select
                      options={Enum.map(ScoringStrategy.get_types(), &{Oli.Utils.snake_case_to_friendly(&1[:type]), &1[:id]})}
                      opts={
                        aria_describedby: "scoringStrategy",
                        placeholder: "Scoring Strategy",
                        disabled: is_disabled(@changeset, @revision)
                      }
                      class="form-control custom-select"
                    />
                  </Field>
                  <small id="scoringStrategy" class="form-text text-muted">The scoring strategy determines how to calculate the final grade book score across all attempts.</small>
                </div>

                <div class="form-group">
                  <Label>Retake Mode</Label>
                  <Field name={:retake_mode}>
                    <Select
                      options={[
                        {"Normal: Students answer all questions in each attempt", :normal},
                        {"Targeted: Students answer only incorrect questions from previous attempts", :targeted}
                      ]}
                      opts={
                        aria_describedby: "retakeMode",
                        placeholder: "Retake Mode",
                        disabled: is_disabled(@changeset, @revision) or !@revision.graded,
                        class: "form-control custom-select"
                      }
                    />
                  </Field>
                  <small id="retakeMode" class="form-text text-muted">The retake mode determines how subsequent attempts are presented to students.</small>
                </div>

                <div class="form-group">
                  <Label>Purpose</Label>
                  <Field name={:purpose}>
                    <Select
                      options={[
                        {"Foundation", :foundation},
                        {"Exploration", :application}
                      ]}
                      opts={
                        aria_describedby: "purpose",
                        placeholder: "Purpose",
                        class: "form-control custom-select"
                      }
                    />
                  </Field>
                </div>

                <div class="form-group">
                  <Label>Related Resources</Label>
                  <Field name={:relates_to}>
                    <HierarchySelector
                      disabled={is_foundation(@changeset, @revision)}
                      id="related-resources-selector"
                      items={@project_hierarchy.children}
                      initial_values={@selected_resources}
                    />
                  </Field>
                </div>
              {/if}
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
              <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">Save</button>
            </div>
          </Form>
        </div>
      </div>
    </div>
    """
  end

  def fetch_field(f, field) do
    case Ecto.Changeset.fetch_field(f, field) do
      {_, value} -> value
      _ -> nil
    end
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
