defmodule Oli.Scenarios.Directives.ActivityBankHandler do
  @moduledoc """
  Handles activity_bank directives.

  Phase 3 wires the directive through schema, parser, and engine dispatch. Phase
  4 will implement operation execution against Oli.Authoring.Editing.ActivityBank.
  """

  alias Oli.Scenarios.DirectiveTypes.{ActivityBankDirective, ExecutionState}

  def handle(%ActivityBankDirective{}, %ExecutionState{}) do
    {:error, "activity_bank directive execution is not implemented yet"}
  end
end
