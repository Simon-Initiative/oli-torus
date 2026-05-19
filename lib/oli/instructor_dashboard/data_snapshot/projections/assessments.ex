defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Assessments do
  @moduledoc """
  Instructor assessments projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector

  @required_oracles [:oracle_instructor_grades, :oracle_instructor_scope_resources]
  @optional_oracles []

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: @optional_oracles

  @spec derive(Contract.t(), keyword()) ::
          {:ok, map()} | {:partial, map(), term()} | {:error, term()}
  def derive(%Contract{} = snapshot, opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      optional = Helpers.optional_oracles(snapshot, @optional_oracles)
      missing_optional = Helpers.missing_optional_oracles(snapshot, @optional_oracles)

      assessments_projection =
        Projector.build(
          Map.get(required, :oracle_instructor_grades, %{}) |> Map.get(:grades, []),
          scope_resource_items:
            Map.get(required, :oracle_instructor_scope_resources, %{}) |> Map.get(:items, []),
          completion_threshold_pct: Keyword.get(opts, :completion_threshold_pct, 50)
        )

      projection =
        Helpers.projection_base(snapshot, :assessments, %{
          assessments: assessments_projection,
          optional_oracles: optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end
end
