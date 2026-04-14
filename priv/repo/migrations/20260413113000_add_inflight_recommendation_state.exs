defmodule Oli.Repo.Migrations.AddInflightRecommendationState do
  use Ecto.Migration

  def change do
    alter table(:instructor_dashboard_recommendation_instances) do
      modify :message, :text, null: true
    end

    create unique_index(
             :instructor_dashboard_recommendation_instances,
             [:section_id],
             name: :recommendation_instances_one_generating_course_scope_idx,
             where: "state = 'generating' AND container_type = 'course' AND container_id IS NULL"
           )

    create unique_index(
             :instructor_dashboard_recommendation_instances,
             [:section_id, :container_id],
             name: :recommendation_instances_one_generating_container_scope_idx,
             where: "state = 'generating' AND container_type = 'container'"
           )
  end
end
