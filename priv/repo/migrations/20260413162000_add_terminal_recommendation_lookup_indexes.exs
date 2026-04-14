defmodule Oli.Repo.Migrations.AddTerminalRecommendationLookupIndexes do
  use Ecto.Migration

  def change do
    create index(
             :instructor_dashboard_recommendation_instances,
             [:section_id, :inserted_at, :id],
             name: :recommendation_instances_latest_terminal_course_scope_idx,
             where:
               "container_type = 'course' AND container_id IS NULL AND state IN ('ready', 'no_signal', 'fallback')"
           )

    create index(
             :instructor_dashboard_recommendation_instances,
             [:section_id, :container_id, :inserted_at, :id],
             name: :recommendation_instances_latest_terminal_container_scope_idx,
             where: "container_type = 'container' AND state IN ('ready', 'no_signal', 'fallback')"
           )
  end
end
