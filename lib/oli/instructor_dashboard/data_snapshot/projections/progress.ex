defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Progress do
  @moduledoc """
  Instructor progress projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector

  @required_oracles [:oracle_instructor_progress_bins, :oracle_instructor_scope_resources]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: []

  @spec derive(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      progress_tile_projection =
        Projector.build(
          snapshot.scope,
          Map.get(required, :oracle_instructor_progress_bins, %{}),
          Map.get(required, :oracle_instructor_scope_resources, %{})
        )

      {:ok,
       Helpers.projection_base(snapshot, :progress, %{
         progress_tile: progress_tile_projection
       })}
    end
  end
end
