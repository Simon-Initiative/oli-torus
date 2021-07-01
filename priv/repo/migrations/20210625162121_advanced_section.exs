defmodule Oli.Repo.Migrations.AdvancedSection do
  use Ecto.Migration

  def change do
    create table(:delivery_policies) do
      add(:assessment_scoring_model, :string)
      add(:assessment_late_submit_policy, :string)
      add(:assessment_grace_period_sec, :integer)
      add(:assessment_time_limit_sec, :integer)
      add(:assessment_feedback_mode, :string)
      add(:assessment_review_answers_policy, :string)
      add(:assessment_num_attempts, :integer)
      add(:section_id, references(:sections))

      timestamps()
    end

    create table(:section_resources) do
      add(:numbering_index, :integer)
      add(:numbering_level, :integer)
      add(:children, {:array, :id}, default: [])
      add(:slug, :string)
      add(:resource_id, :integer)
      add(:project_id, references(:projects))
      add(:section_id, references(:sections))
      add(:delivery_policy_id, references(:delivery_policies))

      timestamps()
    end

    create table(:user_groups) do
      add(:name, :string)
      add(:section_id, references(:sections))
      add(:delivery_policy_id, references(:delivery_policies))

      timestamps()
    end

    create table(:sections_projects_publications, primary_key: false) do
      add(:section_id, references(:sections))
      add(:project_id, references(:projects))
      add(:publication_id, references(:publications))
    end

    create table(:user_group_users, primary_key: false) do
      add(:user_group_id, references(:user_groups))
      add(:user_id, references(:users))
    end

    # TODO: Migrate all start_date and end_date from date to timestamp

    alter table(:sections) do
      remove :start_date, :date
      remove :end_date, :date
      remove :publication_id, references(:projects)
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add(:invite_token, :string)
      add(:passcode, :string)
      add(:root_section_resource_id, references(:section_resources))
      add(:delivery_policy_id, references(:delivery_policies))
    end

    rename(table(:sections), :time_zone, to: :timezone)
    rename(table(:sections), :project_id, to: :base_project_id)

  end
end
