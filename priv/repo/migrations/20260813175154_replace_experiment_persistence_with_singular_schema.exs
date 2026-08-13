defmodule Oli.Repo.Migrations.ReplaceExperimentPersistenceWithSingularSchema do
  use Ecto.Migration

  def up do
    discard_decision_point_experiment_data()

    drop index(:experiment_assignments, [:decision_point_id, :intervention_id, :enrollment_id],
           name: :experiment_assignments_runtime_lookup_idx
         )

    drop index(:experiment_assignments, [:experiment_id, :decision_point_id, :enrollment_id],
           name: :experiment_assignments_legacy_sticky_idx
         )

    drop index(
           :experiment_interventions,
           [:decision_point_id, :page_resource_id, :content_element_id],
           name: :experiment_interventions_identity_idx
         )

    drop table(:experiment_decision_point_conditions)

    alter table(:experiment_definitions) do
      add :alternatives_resource_id, references(:resources, on_delete: :nothing), null: false
      add :prior_alpha, :float, null: false, default: 1.0
      add :prior_beta, :float, null: false, default: 1.0
      add :warm_up_assignments, :integer, null: false, default: 0
      add :max_condition_share, :float, null: false, default: 1.0
      add :fixed_control_allocation, :float
      add :imbalance_threshold, :float, null: false, default: 1.0
      add :reward_source, :string, null: false, default: "assessment_page:normalized_score"
    end

    add_policy_constraints(:experiment_definitions)

    create unique_index(:experiment_definitions, [:alternatives_resource_id],
             where: "state IN ('draft', 'active', 'paused')",
             name: :experiment_definitions_current_alternatives_idx
           )

    create index(:experiment_definitions, [:project_id, :alternatives_resource_id],
             name: :experiment_definitions_group_lookup_idx
           )

    alter table(:experiment_conditions) do
      remove :decision_point_id
      modify :option_id, :string, null: false, from: {:string, null: true}
    end

    create unique_index(:experiment_conditions, [:experiment_id, :option_id],
             name: :experiment_conditions_experiment_option_idx
           )

    create unique_index(:experiment_conditions, [:experiment_id, :id],
             name: :experiment_conditions_experiment_id_idx
           )

    alter table(:experiment_interventions) do
      remove :decision_point_id
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false
    end

    create unique_index(
             :experiment_interventions,
             [:experiment_id, :page_resource_id, :content_element_id],
             name: :experiment_interventions_identity_idx
           )

    create unique_index(:experiment_interventions, [:experiment_id, :id],
             name: :experiment_interventions_experiment_id_idx
           )

    alter table(:experiment_assignments) do
      remove :decision_point_id

      modify :intervention_id, references(:experiment_interventions, on_delete: :nothing),
        null: false,
        from: references(:experiment_interventions, on_delete: :nothing)
    end

    create index(:experiment_assignments, [:experiment_id, :intervention_id, :enrollment_id],
             name: :experiment_assignments_runtime_lookup_idx
           )

    create index(:experiment_assignments, [:experiment_id, :condition_id],
             name: :experiment_assignments_condition_counts_idx
           )

    execute(
      "ALTER TABLE experiment_assignments ADD CONSTRAINT experiment_assignments_intervention_experiment_fkey FOREIGN KEY (experiment_id, intervention_id) REFERENCES experiment_interventions(experiment_id, id)",
      "ALTER TABLE experiment_assignments DROP CONSTRAINT experiment_assignments_intervention_experiment_fkey"
    )

    execute(
      "ALTER TABLE experiment_assignments ADD CONSTRAINT experiment_assignments_condition_experiment_fkey FOREIGN KEY (experiment_id, condition_id) REFERENCES experiment_conditions(experiment_id, id)",
      "ALTER TABLE experiment_assignments DROP CONSTRAINT experiment_assignments_condition_experiment_fkey"
    )

    alter table(:experiment_policy_states) do
      remove :decision_point_id
    end

    create unique_index(:experiment_policy_states, [:experiment_id, :algorithm],
             name: :experiment_policy_states_unique_idx
           )

    drop table(:experiment_decision_points)
  end

  def down do
    discard_singular_experiment_data()

    drop_if_exists index(:experiment_assignments, [:experiment_id, :condition_id],
                     name: :experiment_assignments_condition_counts_idx
                   )

    create table(:experiment_decision_points) do
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false
      add :alternatives_resource_id, references(:resources, on_delete: :nothing), null: false
      add :decision_point_key, :string, null: false
      add :title, :string
      add :position, :integer, null: false, default: 0
      add :prior_alpha, :float, null: false, default: 1.0
      add :prior_beta, :float, null: false, default: 1.0
      add :warm_up_assignments, :integer, null: false, default: 0
      add :max_condition_share, :float, null: false, default: 1.0
      add :fixed_control_allocation, :float
      add :imbalance_threshold, :float, null: false, default: 1.0
      add :reward_source, :string, null: false, default: "assessment_page:normalized_score"

      timestamps(type: :utc_datetime)
    end

    add_policy_constraints(:experiment_decision_points)

    create unique_index(:experiment_decision_points, [:experiment_id, :decision_point_key],
             name: :experiment_decision_points_key_idx
           )

    create index(:experiment_decision_points, [:alternatives_resource_id])

    create index(:experiment_decision_points, [:alternatives_resource_id, :decision_point_key],
             name: :experiment_decision_points_lookup_idx
           )

    drop index(:experiment_policy_states, [:experiment_id, :algorithm],
           name: :experiment_policy_states_unique_idx
         )

    alter table(:experiment_policy_states) do
      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false
    end

    create unique_index(
             :experiment_policy_states,
             [:experiment_id, :decision_point_id, :algorithm],
             name: :experiment_policy_states_unique_idx
           )

    execute(
      "ALTER TABLE experiment_assignments DROP CONSTRAINT experiment_assignments_condition_experiment_fkey"
    )

    execute(
      "ALTER TABLE experiment_assignments DROP CONSTRAINT experiment_assignments_intervention_experiment_fkey"
    )

    drop index(:experiment_conditions, [:experiment_id, :id],
           name: :experiment_conditions_experiment_id_idx
         )

    drop index(:experiment_assignments, [:experiment_id, :intervention_id, :enrollment_id],
           name: :experiment_assignments_runtime_lookup_idx
         )

    alter table(:experiment_assignments) do
      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      modify :intervention_id, references(:experiment_interventions, on_delete: :nothing),
        null: true,
        from: references(:experiment_interventions, on_delete: :nothing)
    end

    create unique_index(
             :experiment_assignments,
             [:experiment_id, :decision_point_id, :enrollment_id],
             where: "intervention_id IS NULL",
             name: :experiment_assignments_legacy_sticky_idx
           )

    create index(:experiment_assignments, [:decision_point_id, :intervention_id, :enrollment_id],
             name: :experiment_assignments_runtime_lookup_idx
           )

    drop index(:experiment_interventions, [:experiment_id, :id],
           name: :experiment_interventions_experiment_id_idx
         )

    drop index(
           :experiment_interventions,
           [:experiment_id, :page_resource_id, :content_element_id],
           name: :experiment_interventions_identity_idx
         )

    alter table(:experiment_interventions) do
      remove :experiment_id

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false
    end

    create unique_index(
             :experiment_interventions,
             [:decision_point_id, :page_resource_id, :content_element_id],
             name: :experiment_interventions_identity_idx
           )

    drop index(:experiment_conditions, [:experiment_id, :option_id],
           name: :experiment_conditions_experiment_option_idx
         )

    alter table(:experiment_conditions) do
      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: true

      modify :option_id, :string, null: true, from: {:string, null: false}
    end

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

    drop index(:experiment_definitions, [:project_id, :alternatives_resource_id],
           name: :experiment_definitions_group_lookup_idx
         )

    drop index(:experiment_definitions, [:alternatives_resource_id],
           name: :experiment_definitions_current_alternatives_idx
         )

    drop_policy_constraints(:experiment_definitions)

    alter table(:experiment_definitions) do
      remove :reward_source
      remove :imbalance_threshold
      remove :fixed_control_allocation
      remove :max_condition_share
      remove :warm_up_assignments
      remove :prior_beta
      remove :prior_alpha
      remove :alternatives_resource_id
    end
  end

  defp discard_decision_point_experiment_data do
    execute("DELETE FROM experiment_accepted_rewards")
    execute("DELETE FROM experiment_assignments")
    execute("DELETE FROM experiment_assessment_bindings")
    execute("DELETE FROM experiment_interventions")
    execute("DELETE FROM experiment_policy_states")
    execute("DELETE FROM experiment_decision_point_conditions")
    execute("DELETE FROM experiment_conditions")
    execute("DELETE FROM experiment_decision_points")
    execute("DELETE FROM experiment_definitions")
  end

  defp discard_singular_experiment_data do
    execute("DELETE FROM experiment_accepted_rewards")
    execute("DELETE FROM experiment_assignments")
    execute("DELETE FROM experiment_assessment_bindings")
    execute("DELETE FROM experiment_interventions")
    execute("DELETE FROM experiment_policy_states")
    execute("DELETE FROM experiment_conditions")
    execute("DELETE FROM experiment_definitions")
  end

  defp add_policy_constraints(table) do
    names = policy_constraint_names(table)

    create constraint(table, names.prior_alpha,
             check: "prior_alpha >= 0.0001 AND prior_alpha <= 1000"
           )

    create constraint(table, names.prior_beta,
             check: "prior_beta >= 0.0001 AND prior_beta <= 1000"
           )

    create constraint(table, names.warm_up, check: "warm_up_assignments >= 0")

    create constraint(table, names.max_share,
             check: "max_condition_share > 0 AND max_condition_share <= 1"
           )

    create constraint(table, names.control_share,
             check:
               "fixed_control_allocation IS NULL OR (fixed_control_allocation >= 0 AND fixed_control_allocation <= 1)"
           )

    create constraint(table, names.imbalance,
             check: "imbalance_threshold >= 0 AND imbalance_threshold <= 1"
           )

    create constraint(table, names.reward_source,
             check: "reward_source = 'assessment_page:normalized_score'"
           )
  end

  defp drop_policy_constraints(table) do
    names = policy_constraint_names(table)

    drop constraint(table, names.prior_alpha)
    drop constraint(table, names.prior_beta)
    drop constraint(table, names.warm_up)
    drop constraint(table, names.max_share)
    drop constraint(table, names.control_share)
    drop constraint(table, names.imbalance)
    drop constraint(table, names.reward_source)
  end

  defp policy_constraint_names(:experiment_definitions) do
    %{
      prior_alpha: :experiment_definitions_prior_alpha_check,
      prior_beta: :experiment_definitions_prior_beta_check,
      warm_up: :experiment_definitions_warm_up_check,
      max_share: :experiment_definitions_max_share_check,
      control_share: :experiment_definitions_control_share_check,
      imbalance: :experiment_definitions_imbalance_check,
      reward_source: :experiment_definitions_reward_source_check
    }
  end

  defp policy_constraint_names(:experiment_decision_points) do
    %{
      prior_alpha: :experiment_decision_points_prior_alpha_check,
      prior_beta: :experiment_decision_points_prior_beta_check,
      warm_up: :experiment_decision_points_warm_up_check,
      max_share: :experiment_decision_points_max_share_check,
      control_share: :experiment_decision_points_control_share_check,
      imbalance: :experiment_decision_points_imbalance_check,
      reward_source: :experiment_decision_points_reward_source_check
    }
  end
end
