defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Progress do
  @moduledoc """
  Instructor progress projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector

  @required_oracles [:oracle_instructor_progress_bins, :oracle_instructor_scope_resources]
  @optional_oracles [:oracle_instructor_schedule_position]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: @optional_oracles

  @spec derive(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      optional = Helpers.optional_oracles(snapshot, @optional_oracles)

      progress_tile_projection =
        Projector.build(
          snapshot.scope,
          Map.get(required, :oracle_instructor_progress_bins, %{}),
          Map.get(required, :oracle_instructor_scope_resources, %{}),
          schedule: Map.get(optional, :oracle_instructor_schedule_position)
        )

      {:ok,
       Helpers.projection_base(snapshot, :progress, %{
         progress_tile: progress_tile_projection
       })}
    end
  end
end
