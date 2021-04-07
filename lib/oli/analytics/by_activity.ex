defmodule Oli.Analytics.ByActivity do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing

  def query_against_project_slug(project_slug) do
    Repo.all(
      from activity in subquery(
             Publishing.query_unpublished_revisions_by_type(project_slug, "activity")
           ),
           left_join: analytics in subquery(Common.analytics_by_activity(project_slug)),
           on: activity.resource_id == analytics.activity_id,
           select: %{
             slice: activity,
             eventually_correct: analytics.eventually_correct,
             first_try_correct: analytics.first_try_correct,
             number_of_attempts: analytics.number_of_attempts,
             relative_difficulty: analytics.relative_difficulty
           },
           preload: [:resource_type]
    )
  end
end
