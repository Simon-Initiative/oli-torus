defmodule Oli.Analytics.ByPage do

  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Repo
  alias Oli.Analytics.Common

  def query_against_project_id(project_id) do
    activity_pages = from snapshot in Snapshot,
      group_by: [snapshot.activity_id, snapshot.resource_id],
      select: %{
        activity_id: snapshot.activity_id,
        page_id: snapshot.resource_id
      }

    Repo.all(
      from page in subquery(Common.all_published_resources(project_id, "page")),
      left_join: pairing in subquery(activity_pages),
      on: page.resource_id == pairing.page_id,
      left_join: activity in subquery(Common.all_published_resources(project_id, "activity")),
      on: pairing.activity_id == activity.resource_id,
      left_join: analytics in subquery(Common.analytics_by_activity()),
      on: pairing.activity_id == analytics.activity_id,
      select: %{
        slice: page,
        activity: activity,
        eventually_correct: analytics.eventually_correct,
        first_try_correct: analytics.first_try_correct,
        number_of_attempts: analytics.number_of_attempts,
        relative_difficulty: analytics.relative_difficulty,
      },
      preload: [:resource_type])
  end

end
