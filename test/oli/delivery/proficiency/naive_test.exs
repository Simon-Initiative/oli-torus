defmodule Oli.Delivery.Proficiency.NaiveTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Proficiency.Naive
  alias Oli.Resources.ResourceType

  test "returns canonical estimates while preserving legacy first-attempt math" do
    section = insert(:section, learning_model_version: :naive)
    user = insert(:user)
    objective = insert(:resource)

    insert(:resource_summary,
      section_id: section.id,
      project_id: -1,
      user_id: user.id,
      resource_id: objective.id,
      resource_type_id: ResourceType.id_for_objective(),
      num_first_attempts_correct: 1,
      num_first_attempts: 5,
      num_correct: 2,
      num_attempts: 6
    )

    objective_id = objective.id
    user_id = user.id

    assert {:ok, %{^objective_id => %{^user_id => estimate}}} =
             Naive.estimates_for_objectives(section, [user.id], [objective.id], [])

    assert_in_delta estimate.score, 0.36, 1.0e-12
    assert estimate.label == :low
    assert estimate.attempt_count == 5
    assert estimate.confidence == nil
    assert estimate.learning_model_version == :naive
  end

  test "keeps the raw ResourceSummary tuple as a naive-only compatibility result" do
    section = insert(:section)
    objective = insert(:resource)

    insert(:resource_summary,
      section_id: section.id,
      project_id: -1,
      user_id: -1,
      resource_id: objective.id,
      resource_type_id: ResourceType.id_for_objective(),
      num_first_attempts_correct: 2,
      num_first_attempts: 3,
      num_correct: 4,
      num_attempts: 5
    )

    assert %{objective.id => {2, 3, 4, 5}} ==
             Naive.raw_proficiency_per_learning_objective(section.id,
               objective_ids: [objective.id]
             )
  end

  test "canonical estimates preserve missing, evidence-gate, and exact bucket boundaries" do
    section = insert(:section, learning_model_version: :naive)
    user = insert(:user)

    [missing, insufficient, at_low, medium, at_medium, high] =
      Enum.map(1..6, fn _ -> insert(:resource) end)

    summaries = [
      {insufficient, 2, 2},
      {at_low, 1, 4},
      {medium, 2, 5},
      {at_medium, 3, 4},
      {high, 4, 5}
    ]

    Enum.each(summaries, fn {objective, correct, attempts} ->
      insert(:resource_summary,
        section_id: section.id,
        project_id: -1,
        user_id: user.id,
        resource_id: objective.id,
        resource_type_id: ResourceType.id_for_objective(),
        num_first_attempts_correct: correct,
        num_first_attempts: attempts,
        num_correct: correct,
        num_attempts: attempts
      )
    end)

    objective_ids = Enum.map([missing, insufficient, at_low, medium, at_medium, high], & &1.id)

    assert {:ok, estimates} =
             Naive.estimates_for_objectives(section, [user.id], objective_ids, [])

    assert estimates[missing.id][user.id].score == nil
    assert estimates[missing.id][user.id].label == :not_enough_information
    assert estimates[insufficient.id][user.id].score == nil
    assert estimates[insufficient.id][user.id].label == :not_enough_information
    assert estimates[at_low.id][user.id].score == 0.4
    assert estimates[at_low.id][user.id].label == :low
    assert estimates[medium.id][user.id].score > 0.4
    assert estimates[medium.id][user.id].label == :medium
    assert estimates[at_medium.id][user.id].score == 0.8
    assert estimates[at_medium.id][user.id].label == :medium
    assert estimates[high.id][user.id].score > 0.8
    assert estimates[high.id][user.id].label == :high
  end
end
