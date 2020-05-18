defmodule Oli.Analytics.ByActivity do

  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Repo

  def query_against_project_id(project_id) do

    activity_num_attempts_rel_difficulty = from snapshot in Snapshot,
      group_by: [snapshot.activity_id],
      select: %{
        activity_id: snapshot.activity_id,
        number_of_attempts: count(snapshot.id),
        relative_difficulty: fragment("sum(? + case when ? is false then 1 else 0 end)::float / count(?)",
          snapshot.hints, snapshot.correct, snapshot.id)
      }

    activity_correctness = from snapshot in Snapshot,
      group_by: [snapshot.activity_id, snapshot.user_id],
      select: %{
        activity_id: snapshot.activity_id,
        user_id: snapshot.user_id,
        is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
        is_first_try_correct: fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
      }

    corrections = from correctness in subquery(activity_correctness),
      group_by: [correctness.activity_id],
      select: %{
        activity_id: correctness.activity_id,
        eventually_correct_ratio: sum(fragment("(case when ? is true then 1 else 0 end)::float", correctness.is_eventually_correct))
          / count(correctness.user_id),
        first_try_correct_ratio: sum(fragment("(case when ? is true then 1 else 0 end)::float", correctness.is_first_try_correct))
          / count(correctness.user_id)
      }

    # all published publications for project
    # all published resources for those publications
    # get unique resource ids
    # join with latest revision
    # filter to activity

    activity = Oli.Resources.ResourceType.get_id_by_type("activity")
    all_activities = from mapping in Oli.Publishing.PublishedResource,
      join: publication in Oli.Publishing.Publication,
      on: mapping.publication_id == publication.id,
      join: rev in Oli.Resources.Revision,
      on: mapping.revision_id == rev.id,
      distinct: rev.resource_id,
      where: publication.project_id == ^project_id
        and publication.published
        and rev.resource_type_id == ^activity,
      select: rev

    Repo.all(from activity in subquery(all_activities),
      left_join: a in subquery(corrections),
      on: activity.resource_id == a.activity_id,
      left_join: b in subquery(activity_num_attempts_rel_difficulty),
      on: a.activity_id == b.activity_id,
      select: %{
        slice: activity,
        eventually_correct: a.eventually_correct_ratio,
        first_try_correct: a.first_try_correct_ratio,
        number_of_attempts: b.number_of_attempts,
        relative_difficulty: b.relative_difficulty,
      },
      preload: [:resource_type])

  end

end
