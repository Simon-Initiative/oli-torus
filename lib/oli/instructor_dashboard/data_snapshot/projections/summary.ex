defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary do
  @moduledoc """
  Instructor summary projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector

  @required_oracles []
  @recommendation_oracle_keys [:oracle_instructor_recommendation]
  @optional_oracles [
                      :oracle_instructor_progress_proficiency,
                      :oracle_instructor_objectives_proficiency,
                      :oracle_instructor_grades,
                      :oracle_instructor_scope_resources
                    ] ++ @recommendation_oracle_keys

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

      summary_tile_projection =
        Projector.build(optional,
          scope: snapshot.scope,
          oracle_statuses: snapshot.oracle_statuses,
          recommendation_oracle_keys:
            Keyword.get(opts, :recommendation_oracle_keys, @recommendation_oracle_keys)
        )

      projection =
        Helpers.projection_base(snapshot, :summary, %{
          required_oracles: required,
          optional_oracles: optional,
          summary_tile: summary_tile_projection
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end
end
