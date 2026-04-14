defmodule Oli.Scenarios.Directives.TimeHandler do
  @moduledoc """
  Handles time directives for deterministic scenario execution.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, TimeDirective}

  def handle(%TimeDirective{at: %DateTime{} = at}, %ExecutionState{} = state) do
    Oli.DateTime.set_override(at)
    {:ok, %{state | scenario_time: at}}
  end
end
