defmodule Oli.Repo.Migrations.AssessmentSettings do
  use Ecto.Migration

   def up do
    alter table(:delivery_settings) do
      add :explanation_strategy, :map

      add :end_date, :utc_datetime
      add :max_attempts, :integer, null: true
      add :password, :string, null: true
      add :time_limit, :integer, null: true
      add :grace_period, :integer, null: true
      add :late_submit, :string, null: true
      add :late_start, :string, null: true
      add :review_submission, :string, null: true
      add :retake_mode, :string, null: true
      add :feedback_mode, :string, null: true
      add :feedback_scheduled_date, :utc_datetime, null: true
      add :scoring_strategy_id, references("scoring_strategies")
    end

    alter table(:section_resources) do
      modify :start_date, :utc_datetime
      modify :end_date, :utc_datetime

      add :collab_space_config, :map
      add :explanation_strategy, :map

      add :max_attempts, :integer, default: -1, null: false
      add :password, :string, null: true
      add :time_limit, :integer, default: 0, null: false
      add :grace_period, :integer, default: 0, null: false
      add :late_submit, :string, default: "allow", null: false
      add :late_start, :string, default: "allow", null: false
      add :review_submission, :string, default: "allow", null: false
      add :retake_mode, :string, default: "normal", null: false
      add :feedback_mode, :string, default: "allow", null: false
      add :feedback_scheduled_date, :utc_datetime, null: true
      add :scoring_strategy_id, references("scoring_strategies")
    end

    flush()

    execute """
    UPDATE section_resources
    SET scoring_strategy_id = 2
    """
  end

  def down do
    alter table(:delivery_settings) do
      remove :explanation_strategy, :map

      remove :end_date, :utc_datetime
      remove :max_attempts, :integer, null: true
      remove :password, :string, null: true
      remove :time_limit, :integer, null: true
      remove :grace_period, :integer, null: true
      remove :late_submit, :string, null: true
      remove :late_start, :string, null: true
      remove :review_submission, :string, null: true
      remove :retake_mode, :string, null: true
      remove :feedback_mode, :string, null: true
      remove :feedback_scheduled_date, :utc_datetime, null: true
      remove :scoring_strategy_id, references("scoring_strategies")
    end

    alter table(:section_resources) do
      modify :start_date, :date
      modify :end_date, :date

      remove :collab_space_config, :map
      remove :explanation_strategy, :map

      remove :max_attempts, :integer, default: -1, null: false
      remove :password, :string, null: true
      remove :time_limit, :integer, default: 0, null: false
      remove :grace_period, :integer, default: 0, null: false
      remove :late_submit, :string, default: "allow", null: false
      remove :late_start, :string, default: "allow", null: false
      remove :review_submission, :string, default: "allow", null: false
      remove :retake_mode, :string, default: "normal", null: false
      remove :feedback_mode, :string, default: "allow", null: false
      remove :feedback_scheduled_date, :utc_datetime, null: true
      remove :scoring_strategy_id, references("scoring_strategies")
    end
  end
end
