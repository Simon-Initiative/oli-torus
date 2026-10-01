defmodule Oli.LearningModel.ConfidenceTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.{Confidence, Config}

  @config Config.defaults()

  test "confidence uses unique part count and the default Hill curve" do
    result = Confidence.calculate(2, @config)

    assert_close(result, 8 / 133)
  end

  test "default confidence reaches Medium at five unique parts and High at eight" do
    for {count, expected, label} <- [
          {0, 0.0, "Low"},
          {4, 64 / 189, "Low"},
          {5, 0.5, "Medium"},
          {7, 343 / 468, "Medium"},
          {8, 512 / 637, "High"}
        ] do
      result = Confidence.calculate(count, @config)
      assert_close(result, expected)
      assert Oli.Delivery.Metrics.confidence_label(result) == label
    end
  end

  test "confidence honors midpoint and fractional steepness overrides" do
    config = %Config{@config | confidence_midpoint: 4.0, confidence_steepness: 0.5}

    for {count, expected} <- [{0, 0.0}, {1, 1 / 3}, {4, 0.5}, {16, 2 / 3}] do
      assert_close(
        Confidence.calculate(count, config),
        expected
      )
    end
  end

  test "confidence is monotonic and bounded even with large powers" do
    values =
      Enum.map(0..100, fn count ->
        Confidence.calculate(count, @config)
      end)

    assert values == Enum.sort(values)
    assert Enum.all?(values, &(&1 >= 0.0 and &1 < 1.0))

    config = %Config{@config | confidence_steepness: 1_000.0}
    assert Confidence.calculate(0, config) == 0.0
    assert Confidence.calculate(5, config) == 0.5
    assert Confidence.calculate(1_000_000, config) == 1.0
  end

  defp assert_close(actual, expected), do: assert_in_delta(actual, expected, 1.0e-12)
end
