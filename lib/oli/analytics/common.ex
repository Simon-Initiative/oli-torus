defmodule Oli.Analytics.Common do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  def analytics_by_activity(project_slug) do
    activity_num_attempts_rel_difficulty =
      from project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.project_id == project.id,
        join: snapshot in Snapshot,
        on: snapshot.section_id == section.id,
        group_by: [snapshot.activity_id],
        select: %{
          activity_id: snapshot.activity_id,
          number_of_attempts: count(snapshot.id),
          relative_difficulty:
            fragment(
              "sum(? + case when ? is false then 1 else 0 end)::float / count(?)",
              snapshot.hints,
              snapshot.correct,
              snapshot.id
            )
        }

    activity_correctness =
      from project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.project_id == project.id,
        join: snapshot in Snapshot,
        on: snapshot.section_id == section.id,
        group_by: [snapshot.activity_id, snapshot.user_id],
        select: %{
          activity_id: snapshot.activity_id,
          user_id: snapshot.user_id,
          is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
          is_first_try_correct:
            fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
        }

    corrections =
      from correctness in subquery(activity_correctness),
        group_by: [correctness.activity_id],
        select: %{
          activity_id: correctness.activity_id,
          eventually_correct_ratio:
            sum(
              fragment(
                "(case when ? is true then 1 else 0 end)::float",
                correctness.is_eventually_correct
              )
            ) /
              count(correctness.user_id),
          first_try_correct_ratio:
            sum(
              fragment(
                "(case when ? is true then 1 else 0 end)::float",
                correctness.is_first_try_correct
              )
            ) /
              count(correctness.user_id)
        }

    from a in subquery(corrections),
      join: b in subquery(activity_num_attempts_rel_difficulty),
      on: a.activity_id == b.activity_id,
      select: %{
        activity_id: a.activity_id,
        eventually_correct: a.eventually_correct_ratio,
        first_try_correct: a.first_try_correct_ratio,
        number_of_attempts: b.number_of_attempts,
        relative_difficulty: b.relative_difficulty
      }
  end
end
