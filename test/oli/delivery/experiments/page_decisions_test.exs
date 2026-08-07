defmodule Oli.Delivery.Experiments.PageDecisionsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Experiments.PageDecisions

  test "returns empty decisions when no resource attempt exists" do
    assert PageDecisions.prepare(%{}, %{resource_attempts: []}) == %{
             alternative_groups_by_id: %{},
             experiment_decisions: %{},
             experiment_attributions: []
           }
  end
end
