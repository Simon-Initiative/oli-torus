defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary do
  @moduledoc """
  Instructor summary projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @required_oracles [:oracle_instructor_progress]
  @optional_oracles [:oracle_instructor_engagement, :oracle_instructor_support]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: @optional_oracles

  @spec derive(Contract.t(), keyword()) ::
          {:ok, map()} | {:partial, map(), term()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      optional = Helpers.optional_oracles(snapshot, @optional_oracles)
      missing_optional = Helpers.missing_optional_oracles(snapshot, @optional_oracles)

      projection =
        Helpers.projection_base(snapshot, :summary, %{
          required_oracles: required,
          optional_oracles: optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end
end
