defmodule Oli.Delivery.ProficiencyIntegrationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Proficiency
  alias Oli.LearningModel.LearningState

  test "integer compatibility clauses load the persisted Section before dispatch" do
    section = insert(:section, learning_model_version: :lkt_aoa)

    assert {:error, {:provider_unavailable, :lkt_aoa}} =
             Proficiency.scope_aggregates(section.id, [:course])
  end

  test "dispatches an LKT-AOA Section to the production objective provider" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    objective = insert(:resource)

    Oli.Repo.insert!(%LearningState{
      section_id: section.id,
      user_id: user.id,
      learning_objective_id: objective.id,
      aoa: 0.7,
      attempt_count: 3,
      unique_activity_part_count: 2,
      confidence: 0.6
    })

    assert {:ok, estimates} =
             Proficiency.estimates_for_objectives(section, [user.id], [objective.id])

    assert estimates[objective.id][user.id].score == 0.7
    assert estimates[objective.id][user.id].learning_model_version == :lkt_aoa
  end
end
