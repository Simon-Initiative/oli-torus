defmodule Oli.Delivery.Attempts.GradingTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.PageLifecycle.Graded
  alias Oli.Delivery.Evaluation.Result

  test "ensure valid grade" do
    assert {0.0, 1.0} == Graded.ensure_valid_grade({-1, -1})
    assert {1.0, 1.0} == Graded.ensure_valid_grade({10, -1})
    assert {9.0, 9.0} == Graded.ensure_valid_grade({10, 9})
    assert {0.0, 1.0} == Graded.ensure_valid_grade({0.0, 0.0})

    assert {0.0, 1.0} == %Result{score: -1.0, out_of: 0.0} |> Graded.ensure_valid_grade()
  end
end
