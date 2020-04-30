defmodule Oli.Repo.Migrations.CreateActivityAccess do
  use Ecto.Migration

  def change do
    create table(:activity_access) do
      add :user_id, :string
      add :section_id, references(:sections)
      add :resource_slug, :string
      add :access_count, :integer
      add :last_accessed, :utc_datetime
      add :date_finished, :utc_datetime
      add :finished_late, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create index(:activity_access, [:section_id])

    create table(:activity_attempts) do
      add :attempt_number, :integer
      add :deadline, :utc_datetime
      add :last_accessed, :utc_datetime
      add :date_completed, :utc_datetime
      add :date_submitted, :utc_datetime
      add :late_submission, :boolean, default: false, null: false
      add :accepted, :boolean, default: false, null: false
      add :processed_by, :string
      add :date_processed, :utc_datetime
      add :activity_access_id, references(:activity_access)

      timestamps(type: :timestamptz)
    end

    create index(:activity_attempts, [:activity_access_id])

    create table(:problem_attempts) do
      add :attempt_number, :integer
      add :problem_id, :string
      add :correct, :boolean, default: false, null: false
      add :date_evaluated, :utc_datetime
      add :children, {:array, :id}
      add :feedback_visible, :boolean, default: false, null: false
      add :hint_visible, :boolean, default: false, null: false
      add :hint, :map
      add :activity_attempts_id, references(:activity_attempts)
      add :parent_id, references(:problem_attempts)

      timestamps(type: :timestamptz)
    end

    create index(:problem_attempts, [:activity_attempts_id])
    create index(:problem_attempts, [:parent_id])

    create table(:interactions) do
      add :interaction_guid, :string
      add :name, :string
      add :problem_attempt_id, references(:problem_attempts, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:interactions, [:problem_attempt_id])

    create table(:responses) do
      add :input_value, :map
      add :current, :boolean, default: false, null: false
      add :interaction_id, references(:interactions, on_delete: :nothing)
      add :problem_attempt_id, references(:problem_attempts, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:responses, [:interaction_id])
    create index(:responses, [:problem_attempt_id])

    create table(:feedbacks) do
      add :assigned_by, :string
      add :body, :map
      add :response_id, references(:responses)
      add :activity_access_id, references(:activity_access)

      timestamps(type: :timestamptz)
    end

    create index(:feedbacks, [:problem_attempt_id])
    create index(:feedbacks, [:activity_access_id])

    create table(:scores) do
      add :score, :decimal
      add :points, :decimal
      add :out_of, :decimal
      add :date_scored, :utc_datetime
      add :assigned_by, :string
      add :score_explanation, :string
      add :override, :decimal
      add :overridden_by, :string
      add :date_overridden, :utc_datetime
      add :activity_access_id, references(:activity_access)
      add :activity_attempt_id, references(:activity_attempts)
      add :problem_attempt_id, references(:problem_attempts)
      add :response_id, references(:responses)

      timestamps(type: :timestamptz)
    end

    create index(:scores, [:activity_access_id])
    create index(:scores, [:activity_attempt_id])
    create index(:scores, [:problem_attempt_id])
    create index(:scores, [:response_id])

  end
end
