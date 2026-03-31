defmodule OliWeb.Delivery.ScoreDisplayTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.ScoreDisplay

  describe "score_status/3" do
    test "returns bad when the score percentage is below the default threshold" do
      assert ScoreDisplay.score_status(3, 10) == :bad
    end

    test "returns good when the score percentage meets the default threshold" do
      assert ScoreDisplay.score_status(4, 10) == :good
    end

    test "returns none when score data is incomplete" do
      assert ScoreDisplay.score_status(nil, 10) == :none
      assert ScoreDisplay.score_status(4, nil) == :none
      assert ScoreDisplay.score_status(4, 0) == :none
    end
  end

  describe "score_status_from_percentage/2" do
    test "uses the default 40 percent threshold" do
      assert ScoreDisplay.score_status_from_percentage(39.9) == :bad
      assert ScoreDisplay.score_status_from_percentage(40.0) == :good
    end
  end
end
