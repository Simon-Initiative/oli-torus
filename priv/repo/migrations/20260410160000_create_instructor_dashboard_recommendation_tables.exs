defmodule Oli.Repo.Migrations.CreateInstructorDashboardRecommendationTables do
  use Ecto.Migration

  def change do
    create table(:instructor_dashboard_recommendation_instances) do
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :container_type, :string, null: false
      add :container_id, :bigint
      add :generation_mode, :string, null: false
      add :state, :string, null: false
      add :message, :text, null: false
      add :prompt_version, :string, null: false
      add :prompt_snapshot, :map, null: false, default: %{}
      add :response_metadata, :map, null: false, default: %{}
      add :generated_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:instructor_dashboard_recommendation_instances, [:section_id, :inserted_at])

    create index(:instructor_dashboard_recommendation_instances, [
             :section_id,
             :container_type,
             :container_id,
             :inserted_at
           ])

    create constraint(
             :instructor_dashboard_recommendation_instances,
             :recommendation_instances_container_scope_check,
             check:
               "(container_type = 'course' AND container_id IS NULL) OR " <>
                 "(container_type = 'container' AND container_id IS NOT NULL)"
           )

    create table(:instructor_dashboard_recommendation_feedback) do
      add :recommendation_instance_id,
          references(:instructor_dashboard_recommendation_instances, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :feedback_type, :string, null: false
      add :feedback_text, :text

      timestamps(type: :utc_datetime)
    end

    create index(:instructor_dashboard_recommendation_feedback, [:recommendation_instance_id])

    create unique_index(
             :instructor_dashboard_recommendation_feedback,
             [:recommendation_instance_id, :user_id],
             name: :recommendation_feedback_unique_sentiment_per_user_idx,
             where: "feedback_type IN ('thumbs_up', 'thumbs_down')"
           )
  end
end
