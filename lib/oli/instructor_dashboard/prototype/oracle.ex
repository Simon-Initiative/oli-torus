defmodule Oli.InstructorDashboard.Prototype.Oracle do
  @moduledoc """
  Minimal oracle behavior for the prototype. No oracle dependencies are modeled here.
  """

  @callback key() :: atom()
  @callback load(Oli.InstructorDashboard.Prototype.Scope.t(), keyword()) ::
              {:ok, term()} | {:error, term()}
end
