defmodule Oli.Analytics.ByActivity do
  import Ecto.Query, warn: false
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing

  def query_against_project_slug(project_slug, filtered_sections) do
    base_query = get_base_query(project_slug, filtered_sections)

    case filtered_sections do
      [] ->
        base_query

      _filtered_sections ->
        get_query_with_join_filter(base_query, filtered_sections)
    end
    |> Repo.all()
  end

  defp get_base_query(project_slug, filtered_sections) do
    subquery =
      if filtered_sections != [] do
        Publishing.query_unpublished_revisions_by_type_and_section(
          project_slug,
          "activity",
          filtered_sections
        )
      else
        Publishing.query_unpublished_revisions_by_type(
          project_slug,
          "activity"
        )
      end

    from activity in subquery(subquery),
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
  end

  defp get_query_with_join_filter(query, filter_list) do
    from activity in query,
      join: resource in assoc(activity, :resource),
      left_join: section_resource in SectionResource,
      on: resource.id == section_resource.resource_id,
      where: section_resource.section_id in ^filter_list
  end
end
