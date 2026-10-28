defmodule Oli.Delivery.Proficiency.EstimateTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Proficiency.Estimate

  test "builds a complete numeric estimate and preserves a real zero score" do
    assert {:ok, estimate} =
             Estimate.new(%{
               section_id: 1,
               user_id: 2,
               learning_objective_id: 3,
               score: 0.0,
               label: :low,
               confidence: 0.4,
               attempt_count: 3,
               unique_activity_part_count: 2,
               learning_model_version: :lkt_aoa
             })

    assert estimate.score == 0.0
    assert estimate.label == :low
  end

  test "represents insufficient evidence without converting it to zero" do
    assert {:ok, estimate} =
             Estimate.new(
               section_id: 1,
               user_id: 2,
               learning_objective_id: 3,
               score: nil,
               label: :not_enough_information,
               confidence: nil,
               learning_model_version: :naive
             )

    assert is_nil(estimate.score)
    assert estimate.attempt_count == 0
  end

  test "rejects invalid ranges, evidence counts, models, and score-label combinations" do
    assert {:error, errors} =
             Estimate.new(%{
               section_id: 0,
               score: 1.1,
               label: :not_enough_information,
               confidence: -0.1,
               attempt_count: -1,
               unique_activity_part_count: 1.5,
               learning_model_version: :other
             })

    assert {:section_id, :must_be_positive} in errors
    assert {:score, :must_be_probability} in errors
    assert {:confidence, :must_be_probability} in errors
    assert {:attempt_count, :must_be_non_negative_integer} in errors
    assert {:unique_activity_part_count, :must_be_non_negative_integer} in errors
    assert {:learning_model_version, :unsupported} in errors
    assert {:score, :inconsistent_with_label} in errors
  end

  test "returns a validation error for unknown fields" do
    assert {:error, unknown_fields: [:extra]} =
             Estimate.new(%{
               section_id: 1,
               label: :not_enough_information,
               learning_model_version: :naive,
               extra: true
             })
  end

  test "returns validation errors when required fields are missing" do
    assert {:error, errors} = Estimate.new(%{})

    assert {:section_id, :must_be_positive} in errors
    assert {:label, :unsupported} in errors
    assert {:learning_model_version, :unsupported} in errors
  end
end
