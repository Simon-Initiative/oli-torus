defmodule Oli.Analytics.Common do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{PartAttempt, ActivityAttempt}
  alias Oli.Activities
  alias OliWeb.Common.FormatDateTime

  def snapshots_for_project(project_slug) do
    objectives_map =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        join: objective in Revision,
        on: snapshot.objective_revision_id == objective.id,
        group_by: [snapshot.objective_revision_id],
        select: {
          snapshot.objective_revision_id,
          objective.title,
          objective.resource_id
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {revision_id, title, resource_id}, acc ->
        Map.put(acc, revision_id, %{title: title, resource_id: resource_id})
      end)

    activities_map =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        join: activity in Revision,
        on: snapshot.activity_revision_id == activity.id,
        group_by: [snapshot.activity_revision_id],
        select: {
          snapshot.activity_revision_id,
          activity.title,
          activity.resource_id,
          activity.activity_type_id,
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {revision_id, title, resource_id, type_id}, acc ->
        Map.put(acc, revision_id, %{title: title, resource_id: resource_id, type_id: type_id})
      end)

    activity_registration_map = Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn {activity_id, registration_id}, acc ->
        Map.put(acc, activity_id, registration_id)
      end)

    sections_map =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        join: section in Section,
        on: snapshot.section_id == section.id,
        group_by: [snapshot.section_id],
        select: {
          snapshot.section_id,
          section.title,
          section.slug
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {section_id, title, slug}, acc ->
        Map.put(acc, section_id, %{title: title, slug: slug})
      end)

    Repo.transaction(fn ->
      Repo.stream(
        from(project in Project,
          where: project.slug == ^project_slug,
          join: snapshot in Snapshot,
          on: snapshot.project_id == project.id,
          join: part_attempt in PartAttempt,
          on: snapshot.part_attempt_id == part_attempt.id,
          join: activity_attempt in ActivityAttempt,
          on: part_attempt.activity_attempt_id == activity_attempt.id,
          select: {
            snapshot.part_attempt_id,
            snapshot.revision_id,
            snapshot.objective_revision_id,
            snapshot.activity_id,
            snapshot.resource_id,
            snapshot.attempt_number,
            snapshot.graded,
            snapshot.correct,
            snapshot.score,
            snapshot.out_of,
            snapshot.hints,
            snapshot.inserted_at,
            snapshot.user_id,
            snapshot.section_id,
            part_attempt.score,
            part_attempt.out_of,
            part_attempt.response,
            part_attempt.feedback,
            part_attempt.activity_attempt_id,
            activity_attempt.resource_attempt_id
          }
        )
      )
      |> Stream.map(fn {
          snapshot_part_attempt_id,
          snapshot_revision_id,
          snapshot_objective_revision_id,
          snapshot_activity_id,
          snapshot_resource_id,
          snapshot_attempt_number,
          snapshot_graded,
          snapshot_correct,
          snapshot_score,
          snapshot_out_of,
          snapshot_hints,
          snapshot_inserted_at,
          snapshot_user_id,
          snapshot_section_id,
          part_attempt_score,
          part_attempt_out_of,
          part_attempt_response,
          part_attempt_feedback,
          part_attempt_activity_attempt_id,
          activity_attempt_resource_attempt_id
      } ->
        objective = Map.get(objectives_map, snapshot_objective_revision_id)
        activity = Map.get(activities_map, snapshot_revision_id)
        activity_registration = Map.get(activity_registration_map, activity.activity_type_id)
        section = Map.get(sections_map, snapshot_section_id)

        [
          snapshot_part_attempt_id,
          snapshot_activity_id,
          snapshot_resource_id,
          objective.resource_id,
          activity.title,
          activity_registration.title,
          objective.title,
          snapshot_attempt_number,
          snapshot_graded,
          snapshot_correct,
          snapshot_score,
          snapshot_out_of,
          snapshot_hints,
          part_attempt_score,
          part_attempt_out_of,
          Jason.encode_to_iodata!(part_attempt_response),
          Jason.encode_to_iodata!(part_attempt_feedback),
          Jason.encode_to_iodata!(activity.content),
          section.title,
          section.slug,
          FormatDateTime.date(snapshot_inserted_at),
          snapshot_user_id,
          part_attempt_activity_attempt_id,
          activity_attempt_resource_attempt_id
        ]
      end)
    end)
  end

  def analytics_by_activity(project_slug) do
    activity_num_attempts_rel_difficulty =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        group_by: [snapshot.activity_id],
        select: %{
          activity_id: snapshot.activity_id,
          number_of_attempts: count(snapshot.part_attempt_id, :distinct),
          relative_difficulty:
            fragment(
              "sum(? + case when ? is false then 1 else 0 end)::float / count(?)",
              snapshot.hints,
              snapshot.correct,
              snapshot.id
            )
        }
      )

    activity_correctness =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        group_by: [snapshot.activity_id, snapshot.user_id],
        select: %{
          activity_id: snapshot.activity_id,
          user_id: snapshot.user_id,
          is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
          is_first_try_correct:
            fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
        }
      )

    corrections =
      from(correctness in subquery(activity_correctness),
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
      )

    from(a in subquery(corrections),
      join: b in subquery(activity_num_attempts_rel_difficulty),
      on: a.activity_id == b.activity_id,
      select: %{
        activity_id: a.activity_id,
        eventually_correct: a.eventually_correct_ratio,
        first_try_correct: a.first_try_correct_ratio,
        number_of_attempts: b.number_of_attempts,
        relative_difficulty: b.relative_difficulty
      }
    )
  end

  def analytics_by_objective(project_slug) do
    activity_num_attempts_rel_difficulty =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        group_by: [snapshot.objective_id],
        select: %{
          objective_id: snapshot.objective_id,
          number_of_attempts: count(snapshot.id),
          relative_difficulty:
            fragment(
              "sum(? + case when ? is false then 1 else 0 end)::float / count(?)",
              snapshot.hints,
              snapshot.correct,
              snapshot.id
            )
        }
      )

    activity_correctness =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        group_by: [snapshot.objective_id, snapshot.user_id, snapshot.activity_id],
        select: %{
          objective_id: snapshot.objective_id,
          user_id: snapshot.user_id,
          activity_id: snapshot.activity_id,
          is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
          is_first_try_correct:
            fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
        }
      )

    corrections =
      from(correctness in subquery(activity_correctness),
        group_by: [correctness.objective_id],
        select: %{
          objective_id: correctness.objective_id,
          eventually_correct_ratio:
            sum(
              fragment(
                "(case when ? is true then 1 else 0 end)::float",
                correctness.is_eventually_correct
              )
            ) /
             fragment("count(distinct (?,?))", correctness.user_id, correctness.activity_id),
          first_try_correct_ratio:
            sum(
              fragment(
                "(case when ? is true then 1 else 0 end)::float",
                correctness.is_first_try_correct
              )
            ) /
              fragment("count(distinct (?,?))", correctness.user_id, correctness.activity_id)
        }
      )

    from(a in subquery(corrections),
      join: b in subquery(activity_num_attempts_rel_difficulty),
      on: a.objective_id == b.objective_id,
      select: %{
        objective_id: a.objective_id,
        eventually_correct: a.eventually_correct_ratio,
        first_try_correct: a.first_try_correct_ratio,
        number_of_attempts: b.number_of_attempts,
        relative_difficulty: b.relative_difficulty
      }
    )
  end
end
