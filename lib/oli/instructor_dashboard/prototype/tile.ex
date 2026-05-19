defmodule Oli.InstructorDashboard.Prototype.Tile do
  @moduledoc """
  Uniform tile interface for declaring oracle dependencies and projections.
  """

  @callback key() :: atom()
  @callback required_oracles() :: %{atom() => module()}
  @callback optional_oracles() :: %{atom() => module()}

  @callback project(Oli.InstructorDashboard.Prototype.Snapshot.t()) ::
              {:ok, map()} | {:error, term()}
end
