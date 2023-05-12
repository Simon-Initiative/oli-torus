defmodule Oli.Repo.Migrations.AssessmentSettings do
  use Ecto.Migration

  def change do
    alter table(:delivery_settings) do
      add :end_date, :utc_datetime
      add :max_attempts, :integer, null: true
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

      add :max_attempts, :integer, default: 0, null: false
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
  end
end
