defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Progress do
  @moduledoc """
  Instructor progress projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @required_oracles [:oracle_instructor_progress]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: []

  @spec derive(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      {:ok,
       Helpers.projection_base(snapshot, :progress, %{
         progress: Map.get(required, :oracle_instructor_progress)
       })}
    end
  end
end
