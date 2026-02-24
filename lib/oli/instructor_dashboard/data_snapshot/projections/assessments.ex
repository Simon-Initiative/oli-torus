defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Assessments do
  @moduledoc """
  Instructor assessments projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @required_oracles [:oracle_instructor_section_analytics]
  @optional_oracles [:oracle_instructor_progress]

  @spec derive(Contract.t(), keyword()) ::
          {:ok, map()} | {:partial, map(), term()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      optional = Helpers.optional_oracles(snapshot, @optional_oracles)
      missing_optional = Helpers.missing_optional_oracles(snapshot, @optional_oracles)

      projection =
        Helpers.projection_base(snapshot, :assessments, %{
          analytics: Map.get(required, :oracle_instructor_section_analytics),
          optional_oracles: optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end
end
