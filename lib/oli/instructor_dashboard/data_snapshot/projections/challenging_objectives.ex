defmodule Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives do
  @moduledoc """
  Instructor challenging-objectives projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @required_oracles [:oracle_instructor_progress]

  @spec derive(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      progress = Map.get(required, :oracle_instructor_progress)

      {:ok,
       Helpers.projection_base(snapshot, :challenging_objectives, %{
         basis: :progress_proxy,
         progress: progress
       })}
    end
  end
end
