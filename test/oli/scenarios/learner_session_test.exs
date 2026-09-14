defmodule Oli.Scenarios.LearnerSessionTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios.LearnerSession

  test "returns one deterministic UUID per learner and section simulation" do
    id = LearnerSession.deterministic_id(42, "learner-a", "section-a")

    assert id == LearnerSession.deterministic_id(42, "learner-a", "section-a")
    refute id == LearnerSession.deterministic_id(42, "learner-b", "section-a")
    refute id == LearnerSession.deterministic_id(42, "learner-a", "section-b")
    assert {:ok, _uuid} = UUID.info(id)
  end

  test "transient lower-level directive IDs remain valid and unique" do
    first = LearnerSession.transient_id()
    second = LearnerSession.transient_id()

    refute first == second
    assert {:ok, _uuid} = UUID.info(first)
  end
end
