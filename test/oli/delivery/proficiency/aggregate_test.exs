defmodule Oli.Delivery.Proficiency.AggregateTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Proficiency.{Aggregate, Estimate}

  test "keeps numeric, categorical, and coverage signals separate" do
    {:ok, estimate} =
      Estimate.new(%{
        section_id: 1,
        score: 0.75,
        label: :medium,
        confidence: 0.9,
        attempt_count: 8,
        unique_activity_part_count: 4,
        learning_model_version: :lkt_aoa
      })

    assert {:ok, aggregate} =
             Aggregate.new(%{
               estimate: estimate,
               numeric_score: 0.75,
               distribution: %{:not_enough_information => 1, medium: 2},
               contributing_count: 2,
               eligible_count: 2,
               total_count: 3,
               coverage: %{based_on: 2, total: 3}
             })

    assert aggregate.numeric_score == 0.75
    assert aggregate.estimate.confidence == 0.9
    assert aggregate.coverage == %{based_on: 2, total: 3}
  end

  test "rejects invalid distributions and count ordering" do
    assert {:error, errors} =
             Aggregate.new(%{
               numeric_score: -0.1,
               distribution: %{unknown: 1},
               contributing_count: 3,
               eligible_count: 2,
               total_count: 1,
               coverage: []
             })

    assert {:numeric_score, :must_be_probability} in errors
    assert {:distribution, :invalid} in errors
    assert {:counts, :out_of_order} in errors
    assert {:coverage, :must_be_map} in errors
  end

  test "returns a validation error for unknown fields" do
    assert {:error, unknown_fields: [:extra]} = Aggregate.new(%{extra: true})
  end
end
