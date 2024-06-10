defmodule Oli.Analytics.ByObjective do
  import Ecto.Query, warn: false
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Resources.ResourceType
  alias Oli.Repo
  alias Oli.Analytics.Common
  alias Oli.Publishing
  alias Oli.Authoring.Course.Project

  def query_against_project_slug(project_slug, []),
    do: get_base_query(project_slug, get_activity_objectives(project_slug), []) |> Repo.all()

  def query_against_project_slug(project_slug, filtered_sections) do
    project_slug
    |> get_base_query(get_activity_objectives(project_slug), filtered_sections)
    |> Repo.all()
  end

  defp get_base_query(project_slug, activity_objectives, filtered_sections) do
    subquery =
      if filtered_sections != [] do
        DeliveryResolver.revisions_by_section_ids(
          filtered_sections,
          ResourceType.id_for_objective()
        )
      else
        Publishing.query_unpublished_revisions_by_type(
          project_slug,
          "objective"
        )
      end

    from(
      objective in subquery(subquery),
      left_join: pairing in subquery(activity_objectives),
      on: objective.resource_id == pairing.objective_id,
      left_join:
        analytics in subquery(Common.analytics_by_objective(project_slug, filtered_sections)),
      on: pairing.objective_id == analytics.objective_id,
      select: %{
        slice: objective,
        eventually_correct: analytics.eventually_correct,
        first_try_correct: analytics.first_try_correct,
        number_of_attempts: analytics.number_of_attempts,
        relative_difficulty: analytics.relative_difficulty
      },
      preload: [:resource_type]
    )
  end

  defp get_activity_objectives(project_slug) do
    from(project in Project,
      where: project.slug == ^project_slug,
      join: snapshot in Snapshot,
      on: snapshot.project_id == project.id,
      group_by: [snapshot.objective_id],
      select: %{
        objective_id: snapshot.objective_id
      }
    )
  end
end
