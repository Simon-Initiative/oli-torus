defmodule Oli.Analytics.Common do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.PartAttempt

  def snapshots_for_project(project_slug) do
    # objectives = from snapshot in Snapshot,
    #   join: objective in Revision,
    #   on: snapshot.objective_id == objective.id,
    #   group_by: [snapshot.objective_id],
    #   select: %{
    #     id: snapshot.objective_id,
    #     title: fragment("concat(? )", objective.title)
    #   }


    # Repo.all(objectives)

    Repo.all(
      from(project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.base_project_id == project.id,
        join: snapshot in Snapshot,
        on: snapshot.section_id == section.id,
        join: activity in Revision,
        on: snapshot.revision_id == activity.id,
        join: objective in Revision,
        on: snapshot.objective_revision_id == objective.id,
        join: pattempt in PartAttempt,
        on: snapshot.part_attempt_id == pattempt.id,
        # group_by: [snapshot.activity_id, snapshot.objective_id],
        select: [
          activity.title,
          activity.activity_type_id,
          objective.title,
          snapshot.attempt_number,
          snapshot.graded,
          snapshot.correct,
          snapshot.score,
          snapshot.out_of,
          snapshot.hints,
          pattempt.score,
          pattempt.out_of,
          pattempt.response,
          pattempt.feedback,
          section.title,
          section.slug
        ]
      )
    )

    # field(:attempt_guid, :string)
    # field(:attempt_number, :integer)
    # field(:date_evaluated, :utc_datetime)
    # field(:score, :float)
    # field(:out_of, :float)
    # field(:response, :map)
    # field(:feedback, :map)
    # field(:hints, {:array, :string}, default: [])
    # field(:part_id, :string)

    # Repo.all(
    #   from(project in Project,
    #     where: project.slug == ^project_slug,
    #     join: section in Section,
    #     on: section.base_project_id == project.id,
    #     join: snapshot in Snapshot,
    #     on: snapshot.section_id == section.id,
    #     join: activity in Revision,
    #     on: snapshot.revision_id == activity.id,
    #     join: objective in Revision,
    #     on: snapshot.objective_id == objective.id,
    #     # group_by: [snapshot.activity_id, snapshot.objective_id],
    #     select: %{
    #       activity: activity,
    #       objective: objective,
    #       attempt_number: snapshot.attempt_number,
    #       correct: snapshot.correct,
    #       graded: snapshot.graded,
    #       hints: snapshot.hints,
    #       out_of: snapshot.out_of,
    #       # part_attempt: snapshot.part_attempt,
    #     }
    #     # select: %{
    #     #   activity_id: snapshot.activity_id,
    #     #   objective_id: snapshot.objective_id
    #     # }
    #   )
    # )
    # Repo.all(
    #   from(project in Project,
    #     where: project.slug == ^project_slug,
    #     join: section in Section,
    #     on: section.base_project_id == project.id,
    #     join: snapshot in Snapshot,
    #     on: snapshot.section_id == section.id,
    #     join: activity in Revision,
    #     on: snapshot.revision_id == activity.id,
    #     join: objective in Revision,
    #     on: snapshot.objective_id == objective.id,
    #     join: pattempt in PartAttempt,
    #     on: snapshot.part_attempt_id == pattempt.id,
    #     group_by: [snapshot.activity_id, snapshot.objective_id],
    #     select: %{
    #       activity: activity.title,
    #       objectives: fragment("concat(?, ', ', ?)", objective.title),
    #       attempt_number: snapshot.attempt_number,
    #       correct: snapshot.correct,
    #       graded: snapshot.graded,
    #       hints: snapshot.hints,
    #       out_of: snapshot.out_of,
    #       part_attempt: pattempt
    #     }
    #   )
    # )

    # Repo.all(
    #   from(project in Project,
    #     where: project.slug == ^project_slug,
    #     join: section in Section,
    #     on: section.base_project_id == project.id,
    #     join: snapshot in Snapshot,
    #     on: snapshot.section_id == section.id,
    #     join: activity in Revision,
    #     on: snapshot.revision_id == activity.id,
    #     join: objective in Revision,
    #     on: snapshot.objective_id == objective.id,
    #     # group_by: [snapshot.activity_id, snapshot.objective_id],
    #     select: %{
    #       activity: activity,
    #       objective: objective,
    #       attempt_number: snapshot.attempt_number,
    #       correct: snapshot.correct,
    #       graded: snapshot.graded,
    #       hints: snapshot.hints,
    #       out_of: snapshot.out_of,
    #       # part_attempt: snapshot.part_attempt,
    #     }
    #     # select: %{
    #     #   activity_id: snapshot.activity_id,
    #     #   objective_id: snapshot.objective_id
    #     # }
    #   )
    # )
    # |> Repo.preload([:user, :part_attempt])

    # subquery =
    #   from t in Publication,
    #     select: %{project_id: t.project_id, max_date: max(t.published)},
    #     where: not is_nil(t.published),
    #     group_by: t.project_id

    # query =
    #   from pub in Publication,
    #     join: u in subquery(subquery),
    #     on: pub.project_id == u.project_id and u.max_date == pub.published,
    #     join: proj in Project,
    #     on: pub.project_id == proj.id,
    #     left_join: a in assoc(proj, :authors),
    #     left_join: v in ProjectVisibility,
    #     on: proj.id == v.project_id,
    #     where:
    #       not is_nil(pub.published) and proj.status == :active and
    #         (a.id == ^author.id or proj.visibility == :global or
    #            (proj.visibility == :selected and
    #               (v.author_id == ^author.id or v.institution_id == ^institution.id))),
    #     preload: [:project],
    #     distinct: true,
    #     select: pub

    # Repo.all(query)

    # subquery =
    #   from t in Publication,
    #     select: %{project_id: t.project_id, max_date: max(t.published)},
    #     where: not is_nil(t.published),
    #     group_by: t.project_id

    # query =
    #   from pub in Publication,
    #     join: u in subquery(subquery),
    #     on: pub.project_id == u.project_id and u.max_date == pub.published,
    #     join: proj in Project,
    #     on: pub.project_id == proj.id,
    #     where:
    #       not is_nil(pub.published) and proj.visibility == :global and proj.status == :active,
    #     preload: [:project],
    #     distinct: true,
    #     select: pub

    # Repo.all(query)
  end

  def analytics_by_activity(project_slug) do
    activity_num_attempts_rel_difficulty =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.base_project_id == project.id,
        # join: spp in SectionsProjectsPublications,
        # on: spp.project_id = project.id,
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
      )

    activity_correctness =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.base_project_id == project.id,
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
end
