defmodule Oli.Analytics.ByActivity do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Analytics.Common

  def query_against_project_id(project_id) do
    Repo.all(
      from activity in subquery(Common.all_published_resources(project_id, "activity")),
      left_join: analytics in subquery(Common.analytics_by_activity()),
      on: activity.resource_id == analytics.activity_id,
      select: %{
        slice: activity,
        eventually_correct: analytics.eventually_correct,
        first_try_correct: analytics.first_try_correct,
        number_of_attempts: analytics.number_of_attempts,
        relative_difficulty: analytics.relative_difficulty,
      },
      preload: [:resource_type])
  end
end
