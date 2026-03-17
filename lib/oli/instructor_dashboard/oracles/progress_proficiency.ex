defmodule Oli.InstructorDashboard.Oracles.ProgressProficiency do
  @moduledoc """
  Returns per-student progress and proficiency tuples for the requested scope.
  """

  use Oli.Dashboard.Oracle

  import Ecto.Query, warn: false

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @impl true
  def key, do: :oracle_instructor_progress_proficiency

  @impl true
  def version, do: 1

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
          proficiency_by_student = proficiency_by_student(section_id, learner_ids, container_id)

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

  defp proficiency_by_student(section_id, learner_ids, container_id) do
    page_type_id = ResourceType.id_for_page()
    container_filter = proficiency_container_filter(section_id, container_id)

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and
          summary.project_id == -1 and
          summary.resource_type_id == ^page_type_id and
          summary.user_id in ^learner_ids,
      where: ^container_filter,
      group_by: summary.user_id,
      select:
        {summary.user_id,
         fragment(
           """
           (
             (1 * CAST(SUM(?) as float)) +
             (0.2 * (CAST(SUM(?) as float) - CAST(SUM(?) as float)))
           ) /
           NULLIF(CAST(SUM(?) as float), 0.0)
           """,
           summary.num_first_attempts_correct,
           summary.num_first_attempts,
           summary.num_first_attempts_correct,
           summary.num_first_attempts
         ), sum(summary.num_first_attempts)}
    )
    |> Repo.all()
    |> Enum.into(%{}, fn {learner_id, proficiency, num_first_attempts} ->
      normalized =
        case num_first_attempts < 3 do
          true -> nil
          false -> proficiency
        end

      {learner_id, normalized}
    end)
  end

  defp proficiency_container_filter(_section_id, nil), do: true

  defp proficiency_container_filter(section_id, container_id) do
    pages_for_container =
      from(cp in ContainedPage,
        where: cp.section_id == ^section_id and cp.container_id == ^container_id,
        select: cp.page_id
      )

    dynamic([summary], summary.resource_id in subquery(pages_for_container))
  end
end
