defmodule Oli.Delivery.Metrics.ProficiencyContractTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Metrics

  test "naive proficiency buckets preserve their exact boundaries" do
    assert Metrics.proficiency_range(0.0, 3) == "Low"
    assert Metrics.proficiency_range(0.4, 3) == "Low"
    assert Metrics.proficiency_range(0.400_001, 3) == "Medium"
    assert Metrics.proficiency_range(0.8, 3) == "Medium"
    assert Metrics.proficiency_range(0.800_001, 3) == "High"
  end

  test "naive proficiency requires three first attempts regardless of score" do
    assert Metrics.proficiency_range(1.0, 0) == "Not enough data"
    assert Metrics.proficiency_range(1.0, 2) == "Not enough data"
    assert Metrics.proficiency_range(nil, 3) == "Not enough data"
  end
end
