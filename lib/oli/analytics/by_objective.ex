defmodule Oli.Analytics.ByObjective do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing
  alias Oli.Authoring.Course.Project

  def query_against_project_slug(project_slug) do
    activity_objectives =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: snapshot in Snapshot,
        on: snapshot.project_id == project.id,
        group_by: [snapshot.objective_id],
        select: %{
          objective_id: snapshot.objective_id,
          number_of_attempts: count(snapshot.id)
        }
      )

    Repo.all(
      from(
        objective in subquery(
          Publishing.query_unpublished_revisions_by_type(project_slug, "objective")
        ),
        left_join: pairing in subquery(activity_objectives),
        on: objective.resource_id == pairing.objective_id,
        left_join: analytics in subquery(Common.analytics_by_objective(project_slug)),
        on: pairing.objective_id == analytics.objective_id,
        select: %{
          slice: objective,
          eventually_correct: analytics.eventually_correct,
          first_try_correct: analytics.first_try_correct,
          number_of_attempts: pairing.number_of_attempts,
          relative_difficulty: analytics.relative_difficulty
        },
        preload: [:resource_type]
      )
    )
  end
end
