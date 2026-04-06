defmodule Oli.InstructorDashboard.Prototype.Tiles.StudentSupport do
  @moduledoc """
  Student Support tile definition with uniform oracle dependency declarations.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Tile

  alias Oli.InstructorDashboard.Prototype.Oracles
  alias Oli.InstructorDashboard.Prototype.Tiles.StudentSupport.Data

  @impl true
  def key, do: :student_support

  @impl true
  def required_oracles do
    %{
      progress: Oracles.Progress,
      proficiency: Oracles.Proficiency,
      enrollments: Oracles.Enrollments
    }
  end

  @impl true
  def optional_oracles, do: %{}

  @impl true
  def project(snapshot) do
    Data.build(snapshot)
  end
end
