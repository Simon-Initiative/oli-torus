defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport do
  @moduledoc """
  Instructor student-support projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector

  @required_oracles [
    :oracle_instructor_progress_proficiency,
    :oracle_instructor_student_info
  ]
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

      support_projection =
        Projector.build(
          Map.get(required, :oracle_instructor_progress_proficiency, []),
          Map.get(required, :oracle_instructor_student_info, []),
          inactivity_days: Keyword.get(opts, :inactivity_days, 7)
        )

      projection =
        Helpers.projection_base(snapshot, :student_support, %{
          support: support_projection,
          optional_oracles: optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end
end
