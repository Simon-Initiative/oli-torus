defmodule Oli.Repo.Migrations.CreateLearningModelOperationalTables do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    create table(:learning_states, primary_key: false) do
      add :section_id, references(:sections, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :user_id, references(:users, on_delete: :delete_all), null: false, primary_key: true

      add :learning_objective_id, references(:resources, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :attempt_count, :bigint, null: false, default: 0
      add :success_score, :float, null: false, default: 0.0
      add :failure_score, :float, null: false, default: 0.0
      add :recency_logit, :float, null: false, default: 0.0
      add :aoa, :float, null: false, default: 0.0
      add :unique_activity_part_count, :bigint, null: false, default: 0
      add :confidence, :float, null: false, default: 0.0

      timestamps(type: :utc_datetime)
    end

    create constraint(:learning_states, :learning_states_attempt_count_non_negative,
             check: "attempt_count >= 0"
           )

    create constraint(:learning_states, :learning_states_unique_part_count_non_negative,
             check: "unique_activity_part_count >= 0"
           )

    create constraint(:learning_states, :learning_states_success_score_non_negative,
             check: "success_score >= 0.0"
           )

    create constraint(:learning_states, :learning_states_failure_score_non_negative,
             check: "failure_score >= 0.0"
           )

    create constraint(:learning_states, :learning_states_aoa_probability_range,
             check: "aoa >= 0.0 AND aoa <= 1.0"
           )

    create constraint(:learning_states, :learning_states_confidence_probability_range,
             check: "confidence >= 0.0 AND confidence <= 1.0"
           )

    create table(:prior_activity_part_evidence, primary_key: false) do
      add :section_id, references(:sections, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :user_id, references(:users, on_delete: :delete_all), null: false, primary_key: true

      add :activity_id, references(:resources, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :part_id, :text, null: false, primary_key: true
      add :inserted_at, :utc_datetime, null: false
    end

    create constraint(
             :prior_activity_part_evidence,
             :prior_activity_part_evidence_part_id_present,
             check: "length(part_id) > 0"
           )

    create table(:learning_model_attempt_applications, primary_key: false) do
      # This narrow append-only projection gives retries an exact database claim
      # without adding processed/update churn to the very large part_attempts table.
      add :part_attempt_id, references(:part_attempts, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :learning_model_version, :string, null: false
      add :applied_at, :utc_datetime, null: false
    end

    create constraint(
             :learning_model_attempt_applications,
             :learning_model_attempts_version_check,
             check: "learning_model_version IN ('naive', 'lkt_aoa')"
           )
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    drop table(:learning_model_attempt_applications)
    drop table(:prior_activity_part_evidence)
    drop table(:learning_states)
  end
end
