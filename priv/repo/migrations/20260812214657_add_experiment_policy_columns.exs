defmodule Oli.Repo.Migrations.AddExperimentPolicyColumns do
  use Ecto.Migration

  def up do
    alter table(:experiment_decision_points) do
      add :prior_alpha, :float, null: false, default: 1.0
      add :prior_beta, :float, null: false, default: 1.0
      add :warm_up_assignments, :integer, null: false, default: 0
      add :max_condition_share, :float, null: false, default: 1.0
      add :fixed_control_allocation, :float
      add :imbalance_threshold, :float, null: false, default: 1.0

      add :reward_source, :string,
        null: false,
        default: "assessment_page:normalized_score"

      remove :policy_config
    end

    alter table(:experiment_definitions) do
      remove :policy_config
    end

    alter table(:experiment_policy_states) do
      remove :prior_config
    end

    create constraint(:experiment_decision_points, :experiment_decision_points_prior_alpha_check,
             check: "prior_alpha >= 0.0001 AND prior_alpha <= 1000"
           )

    create constraint(:experiment_decision_points, :experiment_decision_points_prior_beta_check,
             check: "prior_beta >= 0.0001 AND prior_beta <= 1000"
           )

    create constraint(:experiment_decision_points, :experiment_decision_points_warm_up_check,
             check: "warm_up_assignments >= 0"
           )

    create constraint(:experiment_decision_points, :experiment_decision_points_max_share_check,
             check: "max_condition_share > 0 AND max_condition_share <= 1"
           )

    create constraint(
             :experiment_decision_points,
             :experiment_decision_points_control_share_check,
             check:
               "fixed_control_allocation IS NULL OR (fixed_control_allocation >= 0 AND fixed_control_allocation <= 1)"
           )

    create constraint(:experiment_decision_points, :experiment_decision_points_imbalance_check,
             check: "imbalance_threshold >= 0 AND imbalance_threshold <= 1"
           )

    create constraint(
             :experiment_decision_points,
             :experiment_decision_points_reward_source_check,
             check: "reward_source = 'assessment_page:normalized_score'"
           )
  end

  def down do
    alter table(:experiment_policy_states) do
      add :prior_config, :map, null: false, default: %{}
    end

    alter table(:experiment_definitions) do
      add :policy_config, :map, null: false, default: %{}
    end

    alter table(:experiment_decision_points) do
      add :policy_config, :map, null: false, default: %{}
    end

    drop constraint(:experiment_decision_points, :experiment_decision_points_prior_alpha_check)
    drop constraint(:experiment_decision_points, :experiment_decision_points_prior_beta_check)
    drop constraint(:experiment_decision_points, :experiment_decision_points_warm_up_check)
    drop constraint(:experiment_decision_points, :experiment_decision_points_max_share_check)
    drop constraint(:experiment_decision_points, :experiment_decision_points_control_share_check)
    drop constraint(:experiment_decision_points, :experiment_decision_points_imbalance_check)

    drop constraint(
           :experiment_decision_points,
           :experiment_decision_points_reward_source_check
         )

    alter table(:experiment_decision_points) do
      remove :prior_alpha
      remove :prior_beta
      remove :warm_up_assignments
      remove :max_condition_share
      remove :fixed_control_allocation
      remove :imbalance_threshold
      remove :reward_source
    end
  end
end
