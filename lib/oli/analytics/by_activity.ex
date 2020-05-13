defmodule Oli.Analytics.ByActivity do

  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Repo

  def combined_query(project_id) do
    activity_num_attempts_rel_difficulty = from snapshot in Snapshot,
      group_by: [snapshot.activity_id],
      select: %{
        activity_id: snapshot.activity_id,
        number_of_attempts: count(snapshot.id),
        relative_difficulty: fragment("sum(? + case when ? is false then 1 else 0 end) / count(?)",
          snapshot.hints, snapshot.correct, snapshot.id)
      }

  # users who eventually got the activity correct
  # activity1 user1
    activity_correctness = from snapshot in Snapshot,
      group_by: [snapshot.activity_id, snapshot.user_id],
      select: %{
        activity_id: snapshot.activity_id,
        user_id: snapshot.user_id,
        is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
        is_first_try_correct: fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
      }

  # activity1 .95 .87
  # activity2 1 .95
    corrections = from correctness in subquery(activity_correctness),
      group_by: [correctness.activity_id],
      select: %{
        activity_id: correctness.activity_id,
        eventually_correct_ratio: sum(fragment("case when ? is true then 1 else 0 end", correctness.is_eventually_correct))
          / count(correctness.user_id),
        first_try_correct_ratio: sum(fragment("case when ? is true then 1 else 0 end", correctness.is_first_try_correct))
          / count(correctness.user_id)
      }

    # all published publications for project
    # all published resources for those publications
    # get unique resource ids
    # join with latest revision
    # filter to activity

    # published_publications = from publication in Oli.Publishing.Publication,
    #   where: publication.project_id == ^project.id and publication.published

    # published_resources = from published_resource in Oli.Publishing.PublishedResource,
    #   join: publication in published_publications,
    #   on: publication.id == published_resource.publication_id,
    #   distinct: published_resource.resource_id

    activity = Oli.Resources.ResourceType.get_id_by_type("activity")
    # IO.inspect(Repo.all(Oli.Publishing.PublishedResource), label: "Published resources")
    # IO.inspect(Repo.all(Oli.Publishing.Publication), label: "Publications")
    # IO.inspect(Repo.all(Oli.Resources.Revision), label: "Revisions")
    all_activities = from mapping in Oli.Publishing.PublishedResource,
      join: publication in Oli.Publishing.Publication,
      join: rev in Oli.Resources.Revision,
      on: mapping.publication_id == publication.id,
      on: mapping.revision_id == rev.id,
      where: publication.project_id == ^project_id
        and publication.published
        and rev.resource_type_id == ^activity,
      select: rev

    # IO.inspect Repo.all(all_activities), label: "All revisions"



    # latest_resource_revisions = from resource in published_resources,
    #   join: rev in Oli.Resources.Revision,
    #   on: mapping.revision_id == rev.id,
    #   where: rev.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("activity")
    #     and mapping.publication_id == ^publication_id




    Repo.all(from activity in subquery(all_activities),
      left_join: a in subquery(corrections),
      on: activity.id == a.activity_id,
      left_join: b in subquery(activity_num_attempts_rel_difficulty),
      on: a.activity_id == b.activity_id,
      select: %{
        activity: activity,
        eventually_correct: a.eventually_correct_ratio,
        first_try_correct: a.first_try_correct_ratio,
        number_of_attempts: b.number_of_attempts,
        relative_difficulty: b.relative_difficulty,
      })

    end

end
