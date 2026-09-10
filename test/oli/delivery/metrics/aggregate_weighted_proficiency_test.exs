defmodule Oli.Delivery.Metrics.AggregateWeightedProficiencyTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Metrics

  describe "aggregate_weighted_proficiency/1" do
    test "computes a weighted average across multiple Sub-LOs with different counts" do
      # weighted average = (1.0*10 + 0.5*2) / (10 + 2) = 11.0 / 12 = 0.9166...
      assert {score, total_count} =
               Metrics.aggregate_weighted_proficiency([{1.0, 10}, {0.5, 2}])

      assert_in_delta score, 11.0 / 12, 0.0001
      assert total_count == 12
    end

    test "combines a parent's own directly-tagged evidence with its Sub-LOs' evidence" do
      # parent has its own (0.6, 5) pair in addition to two Sub-LOs
      children = [{0.6, 5}, {1.0, 5}, {0.0, 5}]

      assert {score, total_count} = Metrics.aggregate_weighted_proficiency(children)

      assert_in_delta score, (0.6 * 5 + 1.0 * 5 + 0.0 * 5) / 15, 0.0001
      assert total_count == 15
    end

    test "does not silently drop a Sub-LO with insufficient (but nonzero) evidence" do
      # a Sub-LO with only 1 attempt still contributes its weight to the aggregate
      # instead of being excluded as if only the other Sub-LO existed.
      with_thin_child = Metrics.aggregate_weighted_proficiency([{1.0, 10}, {0.0, 1}])
      without_thin_child = Metrics.aggregate_weighted_proficiency([{1.0, 10}])

      assert with_thin_child != without_thin_child
      assert {score, 11} = with_thin_child
      assert_in_delta score, 10.0 / 11, 0.0001
    end

    test "a wholly unattempted Sub-LO (zero count, nil proficiency) contributes no weight, since it carries no evidence to weight by" do
      # This is expected, not a gap: a zero-count child cannot change a weighted
      # average by definition. The guarantee that thin evidence isn't silently
      # excluded (see the test above) is about never dropping a child that HAS
      # some evidence; it does not imply a child with literally zero evidence
      # should skew the score.
      children = [{1.0, 10}, {nil, 0}]

      assert Metrics.aggregate_weighted_proficiency(children) ==
               Metrics.aggregate_weighted_proficiency([{1.0, 10}])
    end

    test "returns nil score and zero total count when there is no evidence at all" do
      assert Metrics.aggregate_weighted_proficiency([]) == {nil, 0}
      assert Metrics.aggregate_weighted_proficiency([{nil, 0}, {nil, 0}]) == {nil, 0}
    end

    test "produces a deterministic result for repeated calls with the same inputs" do
      children = [{0.7, 4}, {0.3, 6}, {nil, 0}]

      results = for _ <- 1..5, do: Metrics.aggregate_weighted_proficiency(children)

      assert Enum.uniq(results) == [Enum.at(results, 0)]
    end
  end
end
