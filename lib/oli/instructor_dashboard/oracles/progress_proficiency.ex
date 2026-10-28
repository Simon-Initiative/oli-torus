defmodule Oli.InstructorDashboard.Oracles.ProgressProficiency do
  @moduledoc """
  Returns per-student progress and proficiency rows for the requested scope.

  Includes the evidence count even when proficiency is not yet reportable, so
  consumers can distinguish no activity from insufficient proficiency evidence.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Proficiency
  alias Oli.InstructorDashboard.Oracles.Helpers

  @type student_metrics :: %{
          student_id: pos_integer(),
          progress_pct: number(),
          proficiency_pct: number() | nil,
          proficiency_attempt_count: non_neg_integer() | nil
        }

  @impl true
  def key, do: :oracle_instructor_progress_proficiency

  @impl true
  def version, do: 3

  @doc """
  Loads one metrics row per enrolled learner in the selected scope.

  Progress uses a 0..100 scale; proficiency retains the provider's 0..1 score.
  A nil proficiency score means it is not reportable. The attempt count is zero
  when the estimate confirms no attempts, or nil when the estimate is unavailable.
  """
  @impl true
  @spec load(OracleContext.t(), keyword()) :: {:ok, [student_metrics()]} | {:error, term()}
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
          estimates = proficiency_estimates_by_student(section, learner_ids, container_id)

          result =
            learner_ids
            |> Enum.map(fn learner_id ->
              estimate = Map.get(estimates, learner_id, %{})

              %{
                student_id: learner_id,
                progress_pct: Map.get(progress_by_student, learner_id, 0.0) * 100.0,
                proficiency_pct: Map.get(estimate, :score),
                proficiency_attempt_count: Map.get(estimate, :attempt_count)
              }
            end)

          {:ok, result}
      end
    end
  end

  defp proficiency_estimates_by_student(section, learner_ids, container_id) do
    scope = if is_nil(container_id), do: :course, else: {:container, container_id}

    with {:ok, %{^scope => estimates}} <-
           Proficiency.estimates_for_scopes(section, learner_ids, [scope]) do
      estimates
    else
      {:error, _reason} -> %{}
    end
  end
end
