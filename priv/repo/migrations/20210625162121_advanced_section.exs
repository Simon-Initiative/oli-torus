defmodule Oli.Repo.Migrations.AdvancedSection do
  use Ecto.Migration

  def change do

    create table(:section_resources) do
      add :numbering_index, :integer
      add :container_type, :string
      add :children, {:array, :id}, default: []
      add :slug, :string
      add :resource_id, :string
      add :project_id, references(:projects)
      add :section_id, references(:sections)
      add :section_policy_id, references(:section_policies)
    end

    create table(:delivery_policies) do
      add :assessment_scoring_model, :string
      add :assessment_late_submit_policy, :string
      add :assessment_grace_period_sec, :integer
      add :assessment_time_limit_sec, :integer
      add :assessment_feedback_mode, :string
      add :assessment_review_answers_policy, :string
      add :assessment_num_attempts, :integer
      add :section_resource_id, references(:section_resources)
      add :section_id, references(:sections)
      add :user_group_id, references(:user_groups)
    end

    create table(:sections_projects_publications) do
      add :section_id, references(:sections)
      add :project_id, references(:projects)
      add :publication_id, references(:publications)
    end

    create table(:user_groups) do
      add :name, :string
    end

    create table(:user_group_users, primary_key: false) do
      add :user_group_id, references(:user_groups)
      add :user_id, references(:users)
    end

    alter table(:sections) do
      add :invite_token, :string
      add :passcode_hash, :string
      add :base_project_id, references(:projects)
      add :root_section_resource_id, references(:section_resources)
      add :policy_id, references(:policy_id)
    end

    rename table(:sections), :time_zone, to: :timezone


    #TODO: migrate all :project values to new :base_project add

  end
end
