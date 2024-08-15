defmodule Oli.Analytics.ByPage do
  import Ecto.Query, warn: false
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing
  alias Oli.Resources.ResourceType
  alias Oli.Authoring.Course.Project

  def query_against_project_slug(project_slug, []),
    do:
      get_base_query(project_slug, get_activity_pages(project_slug), [])
      |> Repo.all()

  def query_against_project_slug(project_slug, filtered_sections) do
    project_slug
    |> get_base_query(get_activity_pages(project_slug), filtered_sections)
    |> Repo.all()
  end

  defp get_base_query(project_slug, activity_pages, filtered_sections) do
    subquery =
      if filtered_sections != [] do
        DeliveryResolver.project_revisions_by_section_ids(
          filtered_sections,
          project_slug,
          ResourceType.id_for_page()
        )
      else
        Publishing.query_unpublished_revisions_by_type(
          project_slug,
          "page"
        )
      end

    subquery_activity =
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

    from(
      page in subquery(subquery),
      left_join: pairing in subquery(activity_pages),
      on: page.resource_id == pairing.page_id,
      left_join: activity in subquery(subquery_activity),
      on: pairing.activity_id == activity.resource_id,
      left_join:
        analytics in subquery(Common.analytics_by_activity(project_slug, filtered_sections)),
      on: pairing.activity_id == analytics.activity_id,
      select: %{
        slice: page,
        activity: activity,
        eventually_correct: analytics.eventually_correct,
        first_try_correct: analytics.first_try_correct,
        number_of_attempts: analytics.number_of_attempts,
        relative_difficulty: analytics.relative_difficulty
      },
      preload: [:resource_type],
      distinct: [activity]
    )
  end

  defp get_activity_pages(project_slug) do
    from(project in Project,
      where: project.slug == ^project_slug,
      join: snapshot in Snapshot,
      on: snapshot.project_id == project.id,
      group_by: [snapshot.activity_id, snapshot.resource_id],
      select: %{
        activity_id: snapshot.activity_id,
        page_id: snapshot.resource_id
      }
    )
  end
end
