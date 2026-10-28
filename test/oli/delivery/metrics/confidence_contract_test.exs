defmodule Oli.Delivery.Metrics.ConfidenceContractTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.Section

  test "confidence_label/1 buckets preserve their exact boundaries" do
    assert Metrics.confidence_label(0.0) == "Low"
    assert Metrics.confidence_label(0.4) == "Low"
    assert Metrics.confidence_label(0.400_001) == "Medium"
    assert Metrics.confidence_label(0.8) == "Medium"
    assert Metrics.confidence_label(0.800_001) == "High"
    assert Metrics.confidence_label(1.0) == "High"
  end

  test "confidence_per_student_for_objective/3 is always empty for naive sections" do
    section = %Section{learning_model_version: :naive}

    assert Metrics.confidence_per_student_for_objective(section, [1, 2]) == %{}
  end
end
