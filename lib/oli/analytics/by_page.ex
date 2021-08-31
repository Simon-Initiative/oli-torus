defmodule Oli.Analytics.ByPage do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  def query_against_project_slug(project_slug) do
    activity_pages =
      from(project in Project,
        where: project.slug == ^project_slug,
        join: section in Section,
        on: section.base_project_id == project.id,
        join: snapshot in Snapshot,
        on: snapshot.section_id == section.id,
        group_by: [snapshot.activity_id, snapshot.resource_id],
        select: %{
          activity_id: snapshot.activity_id,
          page_id: snapshot.resource_id
        }
      )

    Repo.all(
      from(page in subquery(Publishing.query_unpublished_revisions_by_type(project_slug, "page")),
        left_join: pairing in subquery(activity_pages),
        on: page.resource_id == pairing.page_id,
        left_join:
          activity in subquery(
            Publishing.query_unpublished_revisions_by_type(project_slug, "activity")
          ),
        on: pairing.activity_id == activity.resource_id,
        left_join: analytics in subquery(Common.analytics_by_activity(project_slug)),
        on: pairing.activity_id == analytics.activity_id,
        select: %{
          slice: page,
          activity: activity,
          eventually_correct: analytics.eventually_correct,
          first_try_correct: analytics.first_try_correct,
          number_of_attempts: analytics.number_of_attempts,
          relative_difficulty: analytics.relative_difficulty
        },
        preload: [:resource_type]
      )
    )
  end
end
