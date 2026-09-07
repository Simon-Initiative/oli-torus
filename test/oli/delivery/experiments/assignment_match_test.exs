defmodule Oli.Delivery.Experiments.AssignmentMatchTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Experiments.AssignmentMatch
  alias Oli.Experiments.Schemas.{Assignment, Condition, ExperimentDefinition, Intervention}

  test "hydrates projected schemas while preserving caller-specific fields" do
    match = %{
      assignment: %{id: 1, experiment_id: 2, condition_id: 3},
      experiment: %{id: 2, uuid: Ecto.UUID.generate()},
      condition: %{id: 3, condition_code: "a"},
      intervention: %{id: 4, page_resource_id: 5},
      section_slug: "section-slug"
    }

    hydrated = AssignmentMatch.hydrate(match)

    assert %Assignment{experiment: %ExperimentDefinition{}, condition: %Condition{}} =
             hydrated.assignment

    assert %ExperimentDefinition{id: 2} = hydrated.experiment
    assert %Condition{id: 3, condition_code: "a"} = hydrated.condition
    assert %Intervention{id: 4, page_resource_id: 5} = hydrated.intervention
    assert hydrated.section_slug == "section-slug"
  end
end
