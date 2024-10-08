defmodule Oli.Delivery.Attempts.ScoringTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.Scoring
  alias Oli.Delivery.Evaluation.Result

  test "lookup via id" do
    items = [%{score: 5, out_of: 10}]
    assert %Result{score: 5.0, out_of: 10} = Scoring.calculate_score(1, items)

    items = [%{score: 5, out_of: 10}, %{score: 10, out_of: 20}]
    assert %Result{score: 10.0, out_of: 20} = Scoring.calculate_score(1, items)
  end

  test "average" do
    items = [%{score: 5, out_of: 10}]
    assert %Result{score: 5.0, out_of: 10} = Scoring.calculate_score("average", items)

    items = [%{score: 5, out_of: 10}, %{score: 10, out_of: 20}]
    assert %Result{score: 10.0, out_of: 20} = Scoring.calculate_score("average", items)
  end

  test "most recent" do
    items = [%{score: 5, out_of: 10, date_evaluated: ~U[2021-01-01 00:00:00Z]}]
    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score("most_recent", items)

    items = [
      %{score: 2, out_of: 10, date_evaluated: ~U[2019-01-01 00:00:00Z]},
      %{score: 5, out_of: 10, date_evaluated: ~U[2023-01-01 00:00:00Z]},
      %{score: 1, out_of: 20, date_evaluated: ~U[2021-01-01 00:00:00Z]},
      %{score: 9, out_of: 20, date_evaluated: nil}
    ]

    most_recent_id = Oli.Resources.ScoringStrategy.get_id_by_type("most_recent")
    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score(most_recent_id, items)

    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score("most_recent", items)
  end

  test "best" do
    items = [%{score: 0, out_of: 1}]
    assert %Result{score: 0, out_of: 1} = Scoring.calculate_score("best", items)

    items = [%{score: 5, out_of: 10}]
    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score("best", items)

    items = [%{score: 5, out_of: 10}, %{score: 1, out_of: 20}]
    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score("best", items)
  end

  test "total" do
    items = [%{score: 5, out_of: 10}]
    assert %Result{score: 5, out_of: 10} = Scoring.calculate_score("total", items)

    items = [%{score: 5, out_of: 10}, %{score: 1, out_of: 20}]
    assert %Result{score: 6, out_of: 30} = Scoring.calculate_score("total", items)
  end
end
