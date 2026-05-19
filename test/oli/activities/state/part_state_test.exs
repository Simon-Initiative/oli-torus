defmodule Oli.Activities.State.PartStateTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model.Part
  alias Oli.Activities.State.PartState

  test "from_attempt/3 creates a default state when the attempt is missing" do
    part = %Part{
      id: "janus_formula-1",
      hints: [],
      responses: [],
      parts: [],
      triggers: [],
      grading_approach: :manual,
      out_of: 1
    }

    state = PartState.from_attempt(nil, part, fn _, _ -> :unexpected end)

    assert state.attemptGuid == "janus_formula-1"
    assert state.partId == "janus_formula-1"
    assert state.response == nil
    assert state.score == nil
    assert state.outOf == 1
    assert state.hints == []
    assert state.hasMoreHints == false
  end
end
