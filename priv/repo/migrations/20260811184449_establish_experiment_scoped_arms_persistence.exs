defmodule Oli.Repo.Migrations.EstablishExperimentScopedArmsPersistence do
  use Ecto.Migration

  def up do
    create table(:experiment_decision_point_conditions) do
      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :condition_id, references(:experiment_conditions, on_delete: :nothing), null: false
      add :option_id, :string, null: false
      add :weight, :float, null: false, default: 1.0
      add :position, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create constraint(
             :experiment_decision_point_conditions,
             :experiment_decision_point_conditions_weight_check,
             check: "weight >= 0"
           )

    create unique_index(
             :experiment_decision_point_conditions,
             [:decision_point_id, :condition_id],
             name: :experiment_decision_point_conditions_condition_idx
           )

    create unique_index(:experiment_decision_point_conditions, [:decision_point_id, :option_id],
             name: :experiment_decision_point_conditions_option_idx
           )

    execute("""
    INSERT INTO experiment_decision_point_conditions
      (decision_point_id, condition_id, option_id, weight, position, inserted_at, updated_at)
    SELECT decision_point_id, id, option_id, weight, position, inserted_at, updated_at
    FROM experiment_conditions
    WHERE option_id IS NOT NULL
    """)

    drop_if_exists index(:experiment_conditions, [:decision_point_id, :condition_code],
                     name: :experiment_conditions_code_idx
                   )

    create unique_index(:experiment_conditions, [:experiment_id, :condition_code],
             name: :experiment_conditions_experiment_code_idx
           )

    alter table(:experiment_decision_points) do
      add :algorithm, :string, null: false, default: "weighted_random"
      add :policy_config, :map, null: false, default: %{}
    end

    execute("""
    UPDATE experiment_decision_points AS dp
    SET algorithm = ed.algorithm, policy_config = ed.policy_config
    FROM experiment_definitions AS ed
    WHERE ed.id = dp.experiment_id
    """)

    create constraint(:experiment_decision_points, :experiment_decision_points_algorithm_check,
             check: "algorithm = ANY (ARRAY['weighted_random', 'thompson_sampling'])"
           )

    create table(:experiment_interventions) do
      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :page_resource_id, references(:resources, on_delete: :nothing), null: false
      add :content_element_id, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :experiment_interventions,
             [:decision_point_id, :page_resource_id, :content_element_id],
             name: :experiment_interventions_identity_idx
           )

    create index(:experiment_interventions, [:page_resource_id, :content_element_id],
             name: :experiment_interventions_content_lookup_idx
           )

    create table(:experiment_assessment_bindings) do
      add :intervention_id, references(:experiment_interventions, on_delete: :nothing),
        null: false

      add :assessment_page_resource_id, references(:resources, on_delete: :nothing), null: false
      add :reward_threshold, :decimal, precision: 6, scale: 5, null: false, default: 1.0
      timestamps(type: :utc_datetime)
    end

    create constraint(
             :experiment_assessment_bindings,
             :experiment_assessment_bindings_threshold_check,
             check: "reward_threshold >= 0 AND reward_threshold <= 1"
           )

    create unique_index(:experiment_assessment_bindings, [:intervention_id],
             name: :experiment_assessment_bindings_intervention_idx
           )

    create index(:experiment_assessment_bindings, [:assessment_page_resource_id],
             name: :experiment_assessment_bindings_page_idx
           )

    alter table(:experiment_assignments) do
      add :intervention_id, references(:experiment_interventions, on_delete: :nothing)
    end

    drop_if_exists index(
                     :experiment_assignments,
                     [:experiment_id, :decision_point_id, :enrollment_id],
                     name: :experiment_assignments_sticky_idx
                   )

    create unique_index(
             :experiment_assignments,
             [:experiment_id, :decision_point_id, :enrollment_id],
             where: "intervention_id IS NULL",
             name: :experiment_assignments_legacy_sticky_idx
           )

    create unique_index(:experiment_assignments, [:intervention_id, :enrollment_id],
             where: "intervention_id IS NOT NULL",
             name: :experiment_assignments_intervention_sticky_idx
           )

    create index(:experiment_assignments, [:decision_point_id, :intervention_id, :enrollment_id],
             name: :experiment_assignments_runtime_lookup_idx
           )

    create table(:experiment_accepted_rewards) do
      add :assessment_binding_id,
          references(:experiment_assessment_bindings, on_delete: :nothing), null: false

      add :assignment_id, references(:experiment_assignments, on_delete: :nothing), null: false
      add :enrollment_id, references(:enrollments, on_delete: :nothing), null: false
      add :resource_attempt_id, references(:resource_attempts, on_delete: :nothing), null: false
      add :reward, :integer, null: false
      add :normalized_score, :decimal, precision: 12, scale: 8, null: false
      timestamps(type: :utc_datetime)
    end

    create constraint(:experiment_accepted_rewards, :experiment_accepted_rewards_reward_check,
             check: "reward IN (0, 1)"
           )

    create constraint(
             :experiment_accepted_rewards,
             :experiment_accepted_rewards_normalized_score_check,
             check: "normalized_score >= 0 AND normalized_score <= 1"
           )

    create unique_index(:experiment_accepted_rewards, [:assessment_binding_id, :enrollment_id],
             name: :experiment_accepted_rewards_enrollment_idx
           )

    create unique_index(
             :experiment_accepted_rewards,
             [:assessment_binding_id, :resource_attempt_id],
             name: :experiment_accepted_rewards_attempt_idx
           )

    create index(:experiment_accepted_rewards, [:assignment_id])
  end

  def down do
    drop table(:experiment_accepted_rewards)

    drop index(:experiment_assignments, [:decision_point_id, :intervention_id, :enrollment_id],
           name: :experiment_assignments_runtime_lookup_idx
         )

    drop index(:experiment_assignments, [:experiment_id, :decision_point_id, :enrollment_id],
           name: :experiment_assignments_legacy_sticky_idx
         )

    drop index(:experiment_assignments, [:intervention_id, :enrollment_id],
           name: :experiment_assignments_intervention_sticky_idx
         )

    alter table(:experiment_assignments) do
      remove :intervention_id
    end

    create unique_index(
             :experiment_assignments,
             [:experiment_id, :decision_point_id, :enrollment_id],
             name: :experiment_assignments_sticky_idx
           )

    drop table(:experiment_assessment_bindings)
    drop table(:experiment_interventions)
    drop constraint(:experiment_decision_points, :experiment_decision_points_algorithm_check)

    alter table(:experiment_decision_points) do
      remove :policy_config
      remove :algorithm
    end

    drop index(:experiment_conditions, [:experiment_id, :condition_code],
           name: :experiment_conditions_experiment_code_idx
         )

    create unique_index(:experiment_conditions, [:decision_point_id, :condition_code],
             name: :experiment_conditions_code_idx
           )

    drop table(:experiment_decision_point_conditions)
  end
end
