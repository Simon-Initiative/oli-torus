defmodule Oli.InstructorDashboard.Prototype.Oracles.Proficiency do
  @moduledoc """
  Prototype proficiency oracle returning per-student proficiency.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Oracle

  alias Oli.InstructorDashboard.Prototype.MockData
  alias Oli.InstructorDashboard.Prototype.Scope

  @impl true
  def key, do: :proficiency

  @impl true
  def load(%Scope{}, _opts) do
    by_student =
      MockData.student_ids()
      |> Map.new(fn student_id -> {student_id, MockData.proficiency_percent(student_id)} end)

    {:ok, %{by_student: by_student}}
  end
end
