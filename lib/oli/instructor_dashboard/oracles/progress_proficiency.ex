defmodule Oli.InstructorDashboard.Oracles.ProgressProficiency do
  @moduledoc """
  Returns per-student progress and proficiency tuples for the requested scope.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Proficiency
  alias Oli.InstructorDashboard.Oracles.Helpers

  @impl true
  def key, do: :oracle_instructor_progress_proficiency

  @impl true
  def version, do: 2

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      learner_ids = Helpers.enrolled_learner_ids(section_id)

      case learner_ids do
        [] ->
          {:ok, []}

        _ ->
          container_id = scope.container_id
          progress_by_student = Metrics.progress_for(section_id, learner_ids, container_id)
          section = Helpers.section(section_id)
          proficiency_by_student = proficiency_by_student(section, learner_ids, container_id)

          result =
            learner_ids
            |> Enum.map(fn learner_id ->
              %{
                student_id: learner_id,
                progress_pct: Map.get(progress_by_student, learner_id, 0.0) * 100.0,
                proficiency_pct: Map.get(proficiency_by_student, learner_id)
              }
            end)

          {:ok, result}
      end
    end
  end

  defp proficiency_by_student(section, learner_ids, container_id) do
    scope = if is_nil(container_id), do: :course, else: {:container, container_id}

    with {:ok, %{^scope => estimates}} <-
           Proficiency.estimates_for_scopes(section, learner_ids, [scope]) do
      Map.new(estimates, fn {learner_id, estimate} -> {learner_id, estimate.score} end)
    else
      {:error, _reason} -> %{}
    end
  end
end
