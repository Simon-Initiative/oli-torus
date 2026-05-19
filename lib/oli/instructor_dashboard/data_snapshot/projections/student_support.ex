defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport do
  @moduledoc """
  Instructor student-support projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector
  alias Oli.InstructorDashboard.StudentSupportParameters

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

      active_settings = active_settings(snapshot, opts)

      support_projection =
        Projector.build(
          Map.get(required, :oracle_instructor_progress_proficiency, []),
          Map.get(required, :oracle_instructor_student_info, []),
          projector_opts(active_settings, opts)
        )
        |> Map.put(:parameters, active_settings)

      projection =
        Helpers.projection_base(snapshot, :student_support, %{
          support: support_projection,
          support_parameters: active_settings,
          optional_oracles: optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end

  defp active_settings(%Contract{} = snapshot, opts) do
    case Keyword.fetch(opts, :student_support_settings) do
      {:ok, settings} when is_map(settings) ->
        settings

      _ ->
        case snapshot.metadata do
          %{dashboard_context_type: :section, dashboard_context_id: section_id} ->
            StudentSupportParameters.get_active_settings(section_id)

          _ ->
            StudentSupportParameters.default_settings()
        end
    end
  end

  defp projector_opts(settings, opts) do
    opts
    |> Keyword.take([:now])
    |> Keyword.merge(StudentSupportParameters.to_projector_opts(settings))
  end
end
