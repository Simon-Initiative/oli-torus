defmodule Oli.InstructorDashboard.Prototype.Tiles.Progress do
  @moduledoc """
  Progress tile definition with uniform oracle dependency declarations.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Tile

  alias Oli.InstructorDashboard.Prototype.Oracles
  alias Oli.InstructorDashboard.Prototype.Tiles.Progress.Data

  @impl true
  def key, do: :progress

  @impl true
  def required_oracles do
    %{
      progress: Oracles.Progress,
      contents: Oracles.Contents
    }
  end

  @impl true
  def optional_oracles, do: %{}

  @impl true
  def project(snapshot) do
    Data.build(snapshot)
  end
end
