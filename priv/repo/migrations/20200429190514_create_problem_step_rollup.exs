defmodule Oli.Repo.Migrations.CreateProblemStepRollup do
  use Ecto.Migration

  def change do
    create table(:problem_step_rollup) do
      add :section_slug, :string
      add :user_id, :string
      add :resource_slug, :string
      add :problem_id, :string
      add :step_id, :string
      add :opportunity, :integer
      add :hints, :integer
      add :errors, :integer
      add :attempts, :integer
      add :correct, :integer
      add :first_attempt_correct, :boolean, default: false, null: false
      add :date_correct, :utc_datetime

      timestamps(type: :timestamptz)
    end

  end
end
