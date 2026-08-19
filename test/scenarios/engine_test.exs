defmodule Oli.Scenarios.EngineTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  describe "execute/2 params" do
    test "preserves existing state params when no params option is supplied" do
      state = %ExecutionState{params: %{"existing" => "value"}}

      result = Engine.execute([], state: state)

      assert result.errors == []
      assert result.state.params == %{"existing" => "value"}
    end

    test "replaces existing state params when params option is supplied" do
      state = %ExecutionState{params: %{"existing" => "value"}}

      result = Engine.execute([], state: state, params: %{"new" => "value"})

      assert result.errors == []
      assert result.state.params == %{"new" => "value"}
    end
  end
end
