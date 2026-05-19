defmodule Oli.InstructorDashboard.Prototype.Oracles.Enrollments do
  @moduledoc """
  Prototype enrollments oracle returning student roster information.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Oracle

  alias Oli.InstructorDashboard.Prototype.MockData

  @impl true
  def key, do: :enrollments

  @impl true
  def load(_scope, _opts) do
    {:ok, %{students: MockData.students()}}
  end
end
