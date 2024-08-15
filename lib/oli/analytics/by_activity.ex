defmodule Oli.Analytics.ByActivity do
  import Ecto.Query, warn: false
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Analytics.Common
  alias Oli.Publishing

  def query_against_project_slug(project_slug, []),
    do: get_base_query(project_slug, []) |> Repo.all()

  def query_against_project_slug(project_slug, filtered_sections) do
    project_slug
    |> get_base_query(filtered_sections)
    |> Repo.all()
  end

  defp get_base_query(project_slug, filtered_sections) do
    subquery =
      if filtered_sections != [] do
        DeliveryResolver.project_revisions_by_section_ids(
          filtered_sections,
          project_slug,
          ResourceType.id_for_activity()
        )
      else
        Publishing.query_unpublished_revisions_by_type(
          project_slug,
          "activity"
        )
      end

    from activity in subquery(subquery),
      left_join:
        analytics in subquery(Common.analytics_by_activity(project_slug, filtered_sections)),
      on: activity.resource_id == analytics.activity_id,
      select: %{
        slice: activity,
        eventually_correct: analytics.eventually_correct,
        first_try_correct: analytics.first_try_correct,
        number_of_attempts: analytics.number_of_attempts,
        relative_difficulty: analytics.relative_difficulty
      },
      preload: [:resource_type],
      distinct: [activity]
  end
end
